# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  before do
    neutron_stubs
    @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
      n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      n.set['openstack']['mq']['host'] = '127.0.0.1'
      n.set['chef_client']['splay'] = 300
      n.set['openstack']['network']['quota']['driver'] = 'my.quota.Driver'
      n.set['openstack']['network']['service_provider'] = ['provider1', 'provider2']
    end
    @chef_run.converge 'openstack-network::server'
  end

  it 'does not install neutron-server when nova networking' do
    chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set['openstack']['compute']['network']['service_type'] = 'nova'
    chef_run.converge 'openstack-network::server'
    expect(chef_run).to_not install_package 'neutron-server'
  end

  describe 'package and services' do

    it 'installs neutron packages' do
      expect(@chef_run).to install_package 'neutron-server'
    end

    it 'starts server service' do
      expect(@chef_run).to enable_service 'neutron-server'
    end

    it 'allows overriding service names' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['platform']['neutron_server_service'] = 'my-neutron-server'
      chef_run.converge 'openstack-network::server'

      expect(chef_run).to enable_service 'my-neutron-server'
    end

    it 'allows overriding package options' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['platform']['package_overrides'] = '-o Dpkg::Options::=\'--force-confold\' -o Dpkg::Options::=\'--force-confdef\' --force-yes'
      chef_run.converge 'openstack-network::server'

      expect(chef_run).to install_package('neutron-server').with(options: '-o Dpkg::Options::=\'--force-confold\' -o Dpkg::Options::=\'--force-confdef\' --force-yes')
    end

    it 'allows overriding package names' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['platform']['neutron_server_packages'] = ['my-neutron', 'my-other-neutron']
      chef_run.converge 'openstack-network::server'

      %w{my-neutron my-other-neutron}.each do |pkg|
        expect(chef_run).to install_package(pkg)
      end
    end

    it 'does not install openvswitch package or the agent' do
      expect(@chef_run).not_to install_package 'openvswitch'
      expect(@chef_run).not_to install_package 'neutron-plugin-openvswitch-agent'
      expect(@chef_run).not_to enable_service 'neutron-plugin-openvswitch-agent'
    end

  end

  describe 'api-paste.ini' do

    before do
      @file = @chef_run.template '/etc/neutron/api-paste.ini'
    end

    it 'has proper owner' do
      expect(@file.owner).to eq('neutron')
      expect(@file.group).to eq('neutron')
    end

    it 'has proper modes' do
      expect(sprintf('%o', @file.mode)).to eq '640'
    end

    it 'has neutron pass' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'admin_password = neutron-pass')
    end

    it 'has auth_uri' do
      expect(@chef_run).to render_file(@file.name).with_content(
      'auth_uri = http://127.0.0.1:5000/v2.0')
    end

    it 'has auth_host' do
      expect(@chef_run).to render_file(@file.name).with_content(
      'auth_host = 127.0.0.1')
    end

    it 'has auth_port' do
      expect(@chef_run).to render_file(@file.name).with_content(
      'auth_port = 35357')
    end

    it 'has auth_protocol' do
      expect(@chef_run).to render_file(@file.name).with_content(
      'auth_protocol = http')
    end
  end

  it 'should create neutron-ha-tool.py script' do
    expect(@chef_run).to create_cookbook_file('/usr/local/bin/neutron-ha-tool.py')
  end

  describe 'neutron.conf' do

    before do
      @file = @chef_run.template '/etc/neutron/neutron.conf'
    end

    it 'has proper owner' do
      expect(@file.owner).to eq('neutron')
      expect(@file.group).to eq('neutron')
    end

    it 'has proper modes' do
      expect(sprintf('%o', @file.mode)).to eq '644'
    end

    it 'it sets agent_down_time correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'agent_down_time = 15')
    end

    it 'it sets auth_strategy correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'auth_strategy = keystone')
    end

    it 'it sets state_path correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'state_path = /var/lib/neutron')
    end

    it 'it sets lock_path correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'lock_path = $state_path/lock')
    end

    it 'it sets log_dir correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'log_dir = /var/log/neutron')
    end

    it 'it sets agent report interval correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'report_interval = 4')
    end

    it 'sets rpc_backend correctly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'rpc_backend=neutron.openstack.common.rpc.impl_kombu')
      expect(@chef_run).not_to render_file(@file.name).with_content(
        'rpc_backend=neutron.openstack.common.rpc.impl_qpid')
    end

    it 'it sets root_helper' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"')
    end

    it 'binds to appropriate api ip' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'bind_host = 127.0.0.1')
    end

    it 'binds to appropriate api port' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'bind_port = 9696')
    end

    it 'has appropriate auth host for agents'  do
      expect(@chef_run).to render_file(@file.name).with_content(
        'auth_host = 127.0.0.1')
    end

    it 'has appropriate auth port for agents'  do
      expect(@chef_run).to render_file(@file.name).with_content(
        'auth_port = 5000')
    end

    it 'has appropriate admin password for agents'  do
      expect(@chef_run).to render_file(@file.name).with_content(
        'admin_password = neutron-pass')
    end

    it 'has rabbit_host' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'rabbit_host=127.0.0.1')
    end

    it 'does not have rabbit_hosts' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        'rabbit_hosts=')
    end

    it 'does not have rabbit_ha_queues' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        'rabbit_ha_queues=')
    end

    it 'has rabbit_port' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'rabbit_port=5672')
    end

    it 'has rabbit_userid' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'rabbit_userid=guest')
    end

    it 'has rabbit_password' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'rabbit_password=mq-pass')
    end

    it 'has rabbit_virtual_host' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'rabbit_virtual_host=/')
    end

    it 'has default dhcp_lease_duration setting' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'dhcp_lease_duration = 86400')
    end

    it 'has configurable dhcp_lease_duration setting' do
      @chef_run.node.set['openstack']['network']['dhcp_lease_duration'] = 3600
      @chef_run.converge 'openstack-network::server'
      expect(@chef_run).to render_file(@file.name).with_content(
        'dhcp_lease_duration = 3600')
    end

    it 'does not set service_plugins when attribute is []' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        /^service_plugins =/)
    end

    it 'has default notification_driver setting' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'notification_driver = neutron.openstack.common.notifier.rpc_notifier')
    end

    it 'has configurable notification_driver setting' do
      driver = 'neutron.openstack.common.notifier.no_op_notifier'
      @file = @chef_run.template '/etc/neutron/neutron.conf'
      @chef_run.node.set['openstack']['network']['notification_driver'] = driver
      expect(@chef_run).to render_file(@file.name).with_content(
        "notification_driver = #{driver}")
    end

    it 'has default notification_topics setting' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'notification_topics = notifications')
    end

    it 'has configurable notification_topics setting' do
      topics = 'notifications1,notifications2'
      @file = @chef_run.template '/etc/neutron/neutron.conf'
      @chef_run.node.set['openstack']['mq']['network']['notification_topics'] = topics
      expect(@chef_run).to render_file(@file.name).with_content(
        "notification_topics = #{topics}")
    end

    it 'sets service_plugins' do
      @chef_run.node.set['openstack']['network']['service_plugins'] = %w{
        neutron.foo
        neutron.bar
      }
      @chef_run.converge 'openstack-network::server'

      expect(@chef_run).to render_file(@file.name).with_content(
        'service_plugins = neutron.foo,neutron.bar')
    end

    describe 'qpid' do
      before do
        @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
          n.set['openstack']['compute']['network']['service_type'] = 'neutron'
          n.set['openstack']['mq']['network']['service_type'] = 'qpid'
          n.set['openstack']['mq']['network']['qpid']['username'] = 'guest'
        end
        @chef_run.converge 'openstack-network::server'
      end

      it 'sets rpc_backend correctly' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'rpc_backend=neutron.openstack.common.rpc.impl_qpid')
        expect(@chef_run).not_to render_file(@file.name).with_content(
          'rpc_backend=neutron.openstack.common.rpc.impl_kombu')
      end

      it 'has qpid_hostname' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_hostname=127.0.0.1')
      end

      it 'has qpid_port' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_port=5672')
      end

      it 'has qpid_username' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_username=guest')
      end

      it 'has qpid_password' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_password=mq-pass')
      end

      it 'has qpid_sasl_mechanisms' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_sasl_mechanisms=')
      end

      it 'has qpid_reconnect' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_reconnect=true')
      end

      it 'has qpid_reconnect_timeout' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_reconnect_timeout=0')
      end

      it 'has qpid_reconnect_limit' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_reconnect_limit=0')
      end

      it 'has qpid_reconnect_interval_min' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_reconnect_interval_min=0')
      end

      it 'has qpid_reconnect_interval_max' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_reconnect_interval_max=0')
      end

      it 'has qpid_reconnect_interval' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_reconnect_interval=0')
      end

      it 'has qpid_heartbeat' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_heartbeat=60')
      end

      it 'has qpid_protocol' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_protocol=tcp')
      end

      it 'has qpid_tcp_nodelay' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'qpid_tcp_nodelay=true')
      end
    end

    it 'it does not allow overlapping ips by default' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'allow_overlapping_ips = False')
    end

    it 'it has correct default scheduler classes' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'network_scheduler_driver = neutron.scheduler.dhcp_agent_scheduler.ChanceScheduler')
      expect(@chef_run).to render_file(@file.name).with_content(
        'router_scheduler_driver = neutron.scheduler.l3_agent_scheduler.ChanceScheduler')
    end

    it 'has the overridable default quota values' do
      expect(@chef_run).to render_file(@file.name).with_content(
        /^quota_items = network,subnet,port/)
      expect(@chef_run).to render_file(@file.name).with_content(
        /^default_quota = -1/)
      expect(@chef_run).to render_file(@file.name).with_content(
        /^quota_network = 10/)
      expect(@chef_run).to render_file(@file.name).with_content(
        /^quota_subnet = 10/)
      expect(@chef_run).to render_file(@file.name).with_content(
        /^quota_port = 50/)
      expect(@chef_run).to render_file(@file.name).with_content(
        /^quota_security_group = 10/)
      expect(@chef_run).to render_file(@file.name).with_content(
        /^quota_security_group_rule = 100/)
    end

    it 'writes the quota driver properly' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'quota_driver = my.quota.Driver')
    end

    describe 'neutron.conf with rabbit ha' do

      before do
        @chef_run = ::ChefSpec::Runner.new(::UBUNTU_OPTS) do |n|
          n.set['openstack']['mq']['network']['rabbit']['ha'] = true
          n.set['chef_client']['splay'] = 300
          n.set['openstack']['compute']['network']['service_type'] = 'neutron'
        end
        @chef_run.converge 'openstack-network::server'
      end

      it 'has rabbit_hosts' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'rabbit_hosts=1.1.1.1:5672,2.2.2.2:5672')
      end

      it 'has rabbit_ha_queues' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'rabbit_ha_queues=True')
      end

      it 'does not have rabbit_host' do
        expect(@chef_run).not_to render_file(@file.name).with_content(
          'rabbit_host=127.0.0.1')
      end

      it 'does not have rabbit_port' do
        expect(@chef_run).not_to render_file(@file.name).with_content(
          'rabbit_port=5672')
      end
    end

    describe '/etc/default/neutron-server' do
      before do
        @file = @chef_run.template(
          '/etc/default/neutron-server')
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('root')
        expect(@file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'has a correct plugin config path' do
        expect(@chef_run).to render_file(@file.name).with_content(
          '/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini')
      end
    end

    it 'does not install sysconfig template' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      stub_command(/python/).and_return(true)
      chef_run.converge 'openstack-network::server'
      expect(chef_run).not_to create_file('/etc/sysconfig/neutron')
    end

    describe 'database' do
      it 'has a correct sql_connection value' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'mysql://neutron:neutron@127.0.0.1:3306/neutron')
      end

      it 'sets sqlalchemy attributes' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'slave_connection =')
        expect(@chef_run).to render_file(@file.name).with_content(
          'max_retries = 10')
        expect(@chef_run).to render_file(@file.name).with_content(
          'retry_interval = 10')
        expect(@chef_run).to render_file(@file.name).with_content(
          'min_pool_size = 1')
        expect(@chef_run).to render_file(@file.name).with_content(
          'max_pool_size = 10')
        expect(@chef_run).to render_file(@file.name).with_content(
          'idle_timeout = 3600')
        expect(@chef_run).to render_file(@file.name).with_content(
          'max_overflow = 20')
        expect(@chef_run).to render_file(@file.name).with_content(
          'connection_debug = 0')
        expect(@chef_run).to render_file(@file.name).with_content(
          'connection_trace = false')
        expect(@chef_run).to render_file(@file.name).with_content(
          'pool_timeout = 10')
      end
    end

    it 'sets service_provider attributes' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'service_provider = provider1')
      expect(@chef_run).to render_file(@file.name).with_content(
        'service_provider = provider2')
    end

    describe '/etc/neutron/plugins/ml2/ml2_conf.ini' do
      before do
        @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
        @chef_run.node.set['openstack']['compute']['network']['service_type'] = 'neutron'
        @chef_run.node.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.Ml2InterfaceDriver'
        @chef_run.converge 'openstack-network::server'
        @file = @chef_run.template('/etc/neutron/plugins/ml2/ml2_conf.ini')
      end

      it 'create template ml2_conf.ini' do
        expect(@chef_run).to render_file(@file.name)
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      [
        /^type_drivers = local,flat,vlan,gre,vxlan$/,
        /^tenant_network_types = local$/,
        /^mechanism_drivers = $/,
        /^flat_networks = $/,
        /^network_vlan_ranges = $/,
        /^tunnel_id_ranges = $/,
        /^vni_ranges = $/,
        /^vxlan_group = $/
      ].each do |content|
        it "has a #{content.source[1...-1]} line" do
          expect(@chef_run).to render_file(@file.name).with_content(content)
        end
      end
    end
  end
end
