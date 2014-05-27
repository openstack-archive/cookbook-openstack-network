# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do

      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'uses release db stamp' do
      expect(chef_run).to run_bash('migrate network database').with_code(/stamp icehouse/)
    end

    it 'does not install neutron-server when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'
      expect(chef_run).to_not upgrade_package 'neutron-server'
    end

    describe 'package and services' do
      it 'upgrades neutron-server packages' do
        expect(chef_run).to upgrade_package 'neutron-server'
      end

      it 'allows overriding package names' do
        cust_pkgs = ['my-neutron', 'my-other-neutron']
        node.set['openstack']['network']['platform']['neutron_server_packages'] = cust_pkgs

        cust_pkgs.each do |pkg|
          expect(chef_run).to upgrade_package(pkg)
        end
      end

      it 'starts neutron-server service' do
        expect(chef_run).to enable_service 'neutron-server'
      end

      it 'allows overriding service names' do
        node.set['openstack']['network']['platform']['neutron_server_service'] = 'my-neutron-server'

        expect(chef_run).to enable_service 'my-neutron-server'
      end

      it 'allows overriding package options' do
        cust_opts = "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef' --force-yes"
        node.set['openstack']['network']['platform']['package_overrides'] = cust_opts

        expect(chef_run).to upgrade_package('neutron-server').with(options: cust_opts)
      end

      it 'does not upgrade openvswitch package or the agent' do
        expect(chef_run).not_to upgrade_package 'openvswitch'
        expect(chef_run).not_to upgrade_package 'neutron-plugin-openvswitch-agent'
        expect(chef_run).not_to enable_service 'neutron-plugin-openvswitch-agent'
      end
    end

    describe 'api-paste.ini' do
      let(:file) { chef_run.template('/etc/neutron/api-paste.ini') }

      it 'creates api-paste.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end
    end

    describe 'neutron-ha-tool.py' do
      let(:file) { chef_run.cookbook_file('/usr/local/bin/neutron-ha-tool.py') }

      it 'should create neutron-ha-tool.py script' do
        expect(chef_run).to create_cookbook_file(file.name)
      end
    end

    describe 'neutron.conf' do
      let(:file) { chef_run.template('/etc/neutron/neutron.conf') }

      it 'creates neutron.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it 'it sets rpc_thread_pool_size correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          /^rpc_thread_pool_size = 64$/)
      end

      it 'it sets rpc_conn_pool_size correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          /^rpc_conn_pool_size = 30$/)
      end

      it 'it sets rpc_response_timeout correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          /^rpc_response_timeout = 60$/)
      end

      it 'it sets control_exchange correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          /^control_exchange = neutron$/)
      end

      it 'has default amqp_* queue options set' do
        [/^amqp_durable_queues=false$/,
         /^amqp_auto_delete=false$/].each do |line|
          expect(chef_run).to render_file(file.name).with_content(line)
        end
      end

      it 'it sets agent_down_time correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'agent_down_time = 75')
      end

      it 'writes the quota driver properly' do
        node.set['openstack']['network']['quota']['driver'] = 'my.quota.Driver'

        expect(chef_run).to render_file(file.name).with_content(
          'quota_driver = my.quota.Driver')
      end

      it 'it sets auth_strategy correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'auth_strategy = keystone')
      end

      it 'it sets state_path correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'state_path = /var/lib/neutron')
      end

      it 'it sets lock_path correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'lock_path = $state_path/lock')
      end

      it 'it sets log_dir correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'log_dir = /var/log/neutron')
      end

      it 'it sets agent report interval correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'report_interval = 30')
      end

      it 'it does not allow overlapping ips by default' do
        expect(chef_run).to render_file(file.name).with_content(
          /^allow_overlapping_ips = False$/)
      end

      it 'it has correct default scheduler classes' do
        expect(chef_run).to render_file(file.name).with_content(
          'network_scheduler_driver = neutron.scheduler.dhcp_agent_scheduler.ChanceScheduler')
        expect(chef_run).to render_file(file.name).with_content(
          'router_scheduler_driver = neutron.scheduler.l3_agent_scheduler.ChanceScheduler')
      end

      it 'has the overridable default quota values' do
        expect(chef_run).to render_file(file.name).with_content(
          /^quota_items = network,subnet,port/)
        expect(chef_run).to render_file(file.name).with_content(
          /^default_quota = -1/)
        expect(chef_run).to render_file(file.name).with_content(
          /^quota_network = 10/)
        expect(chef_run).to render_file(file.name).with_content(
          /^quota_subnet = 10/)
        expect(chef_run).to render_file(file.name).with_content(
          /^quota_port = 50/)
        expect(chef_run).to render_file(file.name).with_content(
          /^quota_security_group = 10/)
        expect(chef_run).to render_file(file.name).with_content(
          /^quota_security_group_rule = 100/)
      end

      it 'sets rpc_backend correctly' do
        expect(chef_run).to render_file(file.name).with_content(
          'rpc_backend=neutron.openstack.common.rpc.impl_kombu')
        expect(chef_run).not_to render_file(file.name).with_content(
          'rpc_backend=neutron.openstack.common.rpc.impl_qpid')
      end

      it 'it sets root_helper' do
        expect(chef_run).to render_file(file.name).with_content(
          'root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"')
      end

      it 'binds to appropriate api ip' do
        expect(chef_run).to render_file(file.name).with_content(
          'bind_host = 127.0.0.1')
      end

      it 'binds to appropriate api port' do
        expect(chef_run).to render_file(file.name).with_content(
          'bind_port = 9696')
      end

      it 'has rabbit_host' do
        expect(chef_run).to render_file(file.name).with_content(
          'rabbit_host=127.0.0.1')
      end

      it 'does not have rabbit_hosts' do
        expect(chef_run).not_to render_file(file.name).with_content(
          'rabbit_hosts=')
      end

      it 'does not have rabbit_ha_queues' do
        expect(chef_run).not_to render_file(file.name).with_content(
          'rabbit_ha_queues=')
      end

      it 'has rabbit_port' do
        expect(chef_run).to render_file(file.name).with_content(
          'rabbit_port=5672')
      end

      it 'has rabbit_userid' do
        expect(chef_run).to render_file(file.name).with_content(
          'rabbit_userid=guest')
      end

      it 'has rabbit_password' do
        expect(chef_run).to render_file(file.name).with_content(
          'rabbit_password=mq-pass')
      end

      it 'has rabbit_virtual_host' do
        expect(chef_run).to render_file(file.name).with_content(
          'rabbit_virtual_host=/')
      end

      it 'has default dhcp_lease_duration setting' do
        expect(chef_run).to render_file(file.name).with_content(
          'dhcp_lease_duration = 86400')
      end

      it 'has configurable dhcp_lease_duration setting' do
        node.set['openstack']['network']['dhcp_lease_duration'] = 3600

        expect(chef_run).to render_file(file.name).with_content(
          'dhcp_lease_duration = 3600')
      end

      it 'does not set service_plugins when attribute is []' do
        expect(chef_run).not_to render_file(file.name).with_content(
          /^service_plugins =/)
      end

      it 'has default notification_driver setting' do
        expect(chef_run).to render_file(file.name).with_content(
          'notification_driver = neutron.openstack.common.notifier.rpc_notifier')
      end

      it 'has configurable notification_driver setting' do
        driver = 'neutron.openstack.common.notifier.no_op_notifier'
        node.set['openstack']['network']['notification_driver'] = driver

        expect(chef_run).to render_file(file.name).with_content(
          "notification_driver = #{driver}")
      end

      it 'has default notification_topics setting' do
        expect(chef_run).to render_file(file.name).with_content(
          'notification_topics = notifications')
      end

      it 'has configurable notification_topics setting' do
        topics = 'notifications1,notifications2'
        node.set['openstack']['mq']['network']['notification_topics'] = topics

        expect(chef_run).to render_file(file.name).with_content(
          "notification_topics = #{topics}")
      end

      it 'sets service_plugins' do
        node.set['openstack']['network']['service_plugins'] = %w{
          neutron.foo
          neutron.bar
        }

        expect(chef_run).to render_file(file.name).with_content(
          'service_plugins = neutron.foo,neutron.bar')
      end

      it 'has neutron pass' do
        expect(chef_run).to render_file(file.name).with_content(
          'admin_password = neutron-pass')
      end

      it 'has auth_uri' do
        expect(chef_run).to render_file(file.name).with_content(
          'auth_uri = http://127.0.0.1:5000/v2.0')
      end

      it 'has auth_host' do
        expect(chef_run).to render_file(file.name).with_content(
          'auth_host = 127.0.0.1')
      end

      it 'has auth_port' do
        expect(chef_run).to render_file(file.name).with_content(
          'auth_port = 35357')
      end

      it 'has auth_protocol' do
        expect(chef_run).to render_file(file.name).with_content(
          'auth_protocol = http')
      end

      it 'has signing_dir' do
        expect(chef_run).to render_file(file.name).with_content(
          'signing_dir = /var/lib/neutron/keystone-signing')
      end

      it 'has correct auth_version' do
        expect(chef_run).not_to render_file(file.name).with_content(
          'auth_version = v2.0')
      end

      describe 'qpid' do
        before do
          node.set['openstack']['mq']['network']['service_type'] = 'qpid'
          node.set['openstack']['mq']['network']['qpid']['username'] = 'guest'
        end

        it 'sets rpc_backend correctly' do
          expect(chef_run).to render_file(file.name).with_content(
            'rpc_backend=neutron.openstack.common.rpc.impl_qpid')
          expect(chef_run).not_to render_file(file.name).with_content(
            'rpc_backend=neutron.openstack.common.rpc.impl_kombu')
        end

        it 'has qpid_hostname' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_hostname=127.0.0.1')
        end

        it 'has qpid_port' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_port=5672')
        end

        it 'has qpid_username' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_username=guest')
        end

        it 'has qpid_password' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_password=mq-pass')
        end

        it 'has qpid_sasl_mechanisms' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_sasl_mechanisms=')
        end

        it 'has qpid_reconnect' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_reconnect=true')
        end

        it 'has qpid_reconnect_timeout' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_reconnect_timeout=0')
        end

        it 'has qpid_reconnect_limit' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_reconnect_limit=0')
        end

        it 'has qpid_reconnect_interval_min' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_reconnect_interval_min=0')
        end

        it 'has qpid_reconnect_interval_max' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_reconnect_interval_max=0')
        end

        it 'has qpid_reconnect_interval' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_reconnect_interval=0')
        end

        it 'has qpid_heartbeat' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_heartbeat=60')
        end

        it 'has qpid_protocol' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_protocol=tcp')
        end

        it 'has qpid_tcp_nodelay' do
          expect(chef_run).to render_file(file.name).with_content(
            'qpid_tcp_nodelay=true')
        end

        it 'has qpid_topology_version set' do
          expect(chef_run).to render_file(file.name).with_content(
            /^qpid_topology_version=1$/)
        end
      end

      describe 'neutron.conf with rabbit ha' do
        before do
          node.set['openstack']['mq']['network']['rabbit']['ha'] = true
          node.set['chef_client']['splay'] = 300
        end

        it 'has rabbit_hosts' do
          expect(chef_run).to render_file(file.name).with_content(
            'rabbit_hosts=1.1.1.1:5672,2.2.2.2:5672')
        end

        it 'has rabbit_ha_queues' do
          expect(chef_run).to render_file(file.name).with_content(
            'rabbit_ha_queues=True')
        end

        it 'does not have rabbit_host' do
          expect(chef_run).not_to render_file(file.name).with_content(
            'rabbit_host=127.0.0.1')
        end

        it 'does not have rabbit_port' do
          expect(chef_run).not_to render_file(file.name).with_content(
            'rabbit_port=5672')
        end
      end

      it 'does not create sysconfig template' do
        stub_command(/python/).and_return(true)
        expect(chef_run).not_to create_file('/etc/sysconfig/neutron')
      end

      describe 'database' do
        it 'has a correct sql_connection value' do
          expect(chef_run).to render_file(file.name).with_content(
            'mysql://neutron:neutron@127.0.0.1:3306/neutron')
        end

        it 'sets sqlalchemy attributes' do
          expect(chef_run).to render_file(file.name).with_content(
            'slave_connection =')
          expect(chef_run).to render_file(file.name).with_content(
            'max_retries = 10')
          expect(chef_run).to render_file(file.name).with_content(
            'retry_interval = 10')
          expect(chef_run).to render_file(file.name).with_content(
            'min_pool_size = 1')
          expect(chef_run).to render_file(file.name).with_content(
            'max_pool_size = 10')
          expect(chef_run).to render_file(file.name).with_content(
            'idle_timeout = 3600')
          expect(chef_run).to render_file(file.name).with_content(
            'max_overflow = 20')
          expect(chef_run).to render_file(file.name).with_content(
            'connection_debug = 0')
          expect(chef_run).to render_file(file.name).with_content(
            'connection_trace = false')
          expect(chef_run).to render_file(file.name).with_content(
            'pool_timeout = 10')
        end
      end

      it 'sets service_provider attributes' do
        node.set['openstack']['network']['service_provider'] = ['provider1', 'provider2']

        expect(chef_run).to render_file(file.name).with_content(
          'service_provider = provider1')
        expect(chef_run).to render_file(file.name).with_content(
          'service_provider = provider2')
      end

      it 'has the overridable default nova interaction values' do
        expect(chef_run).to render_file(file.name).with_content(
          'notify_nova_on_port_status_changes = True')
        expect(chef_run).to render_file(file.name).with_content(
          'notify_nova_on_port_data_changes = True')
        expect(chef_run).to render_file(file.name).with_content(
          'nova_url = http://127.0.0.1:8774/v2')
        expect(chef_run).to render_file(file.name).with_content(
          'nova_region_name = RegionOne')
        expect(chef_run).to render_file(file.name).with_content(
          'nova_admin_username = nova')
        expect(chef_run).to render_file(file.name).with_content(
          'nova_admin_tenant_id =')
        expect(chef_run).to render_file(file.name).with_content(
          'nova_admin_password = nova-pass')
        expect(chef_run).to render_file(file.name).with_content(
          'nova_admin_auth_url = http://127.0.0.1:35357/v2.0')
        expect(chef_run).to render_file(file.name).with_content(
          'send_events_interval = 2')
        expect(chef_run).to run_ruby_block('query service tenant uuid')
      end

      describe 'query service tenant uuid' do
        it 'has queried service tenant uuid for nova interactions' do
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('000-UUID-FROM-CLI')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 000-UUID-FROM-CLI')
        end

        it 'has status changes for nova interactions disabled without id override' do
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_status_changes'] = 'False'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('000-UUID-FROM-CLI')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 000-UUID-FROM-CLI')
        end

        it 'has data changes for nova interactions disabled without id override' do
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_data_changes'] = 'False'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('000-UUID-FROM-CLI')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 000-UUID-FROM-CLI')
        end

        it 'has all changes for nova interactions disabled without id override' do
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_status_changes'] = 'False'
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_data_changes'] = 'False'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq(nil)
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id =')
        end

        it 'has status changes for nova interactions disabled with id override' do
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_status_changes'] = 'False'
          chef_run.node.set['openstack']['network']['nova']['admin_tenant_id'] = '111-UUID-OVERRIDE'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('111-UUID-OVERRIDE')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 111-UUID-OVERRIDE')
        end

        it 'has data changes for nova interactions disabled with id override' do
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_data_changes'] = 'False'
          chef_run.node.set['openstack']['network']['nova']['admin_tenant_id'] = '111-UUID-OVERRIDE'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('111-UUID-OVERRIDE')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 111-UUID-OVERRIDE')
        end

        it 'has all changes for nova interactions disabled with id override' do
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_status_changes'] = 'False'
          chef_run.node.set['openstack']['network']['nova']['notify_nova_on_port_data_changes'] = 'False'
          chef_run.node.set['openstack']['network']['nova']['admin_tenant_id'] = '111-UUID-OVERRIDE'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('111-UUID-OVERRIDE')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 111-UUID-OVERRIDE')
        end

        it 'has overriden service tenant uuid for nova interactions' do
          chef_run.node.set['openstack']['network']['nova']['admin_tenant_id'] = '111-UUID-OVERRIDE'
          # run actual ruby_block resource
          chef_run.find_resource(:ruby_block, 'query service tenant uuid').old_run_action(:create)
          nova_tenant_id = chef_run.node['openstack']['network']['nova']['admin_tenant_id']
          expect(nova_tenant_id).to eq('111-UUID-OVERRIDE')
          expect(chef_run).to render_file(file.name).with_content(
            'nova_admin_tenant_id = 111-UUID-OVERRIDE')
        end
      end
    end

    describe '/etc/default/neutron-server' do
      let(:file) { chef_run.template('/etc/default/neutron-server') }

      it 'creates /etc/default/neutron-server' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0644
        )
      end

      it 'has a correct plugin config path' do
        expect(chef_run).to render_file(file.name).with_content(
          '/etc/neutron/plugins/ml2/ml2_conf.ini')
      end
    end

    describe '/etc/neutron/plugins/ml2/ml2_conf.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/ml2/ml2_conf.ini') }

      before do
        node.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.Ml2InterfaceDriver'
      end

      it 'creates ml2_conf.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      [
        /^type_drivers = local,flat,vlan,gre,vxlan$/,
        /^tenant_network_types = local$/,
        /^mechanism_drivers = openvswitch$/,
        /^flat_networks = $/,
        /^network_vlan_ranges = $/,
        /^tunnel_id_ranges = $/,
        /^vni_ranges = $/,
        /^vxlan_group = $/,
        /^enable_security_group = True$/
      ].each do |content|
        it "has a #{content.source[1...-1]} line" do
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end
    end
  end
end
