# Encoding: utf-8
require 'chefspec'
require 'chefspec/berkshelf'

ChefSpec::Coverage.start! { add_filter 'openstack-network' }

require 'chef/application'

LOG_LEVEL = :fatal
SUSE_OPTS = {
  platform: 'suse',
  version: '11.3',
  log_level: LOG_LEVEL
}
REDHAT_OPTS = {
  platform: 'redhat',
  version: '7.1',
  log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '14.04',
  log_level: LOG_LEVEL
}
CENTOS_OPTS = {
  platform: 'centos',
  version: '6.5',
  log_level: LOG_LEVEL
}

MOCK_NODE_NETWORK_DATA =
  {
    'ipaddress' => '10.0.0.2',
    'fqdn' => 'localhost.localdomain',
    'hostname' => 'localhost',
    'network' => {
      'default_interface' => 'eth0',
      'interfaces' => {
        'eth0' => {
          'addresses' => {
            'fe80::a00:27ff:feca:ab08' => { 'scope' => 'Link', 'prefixlen' => '64', 'family' => 'inet6' },
            '10.0.0.2' => { 'netmask' => '255.255.255.0', 'broadcast' => '10.0.0.255', 'family' => 'inet' },
            '08:00:27:CA:AB:08' => { 'family' => 'lladdr' }
          }
        },
        'lo' => {
          'addresses' => {
            '::1' => { 'scope' => 'Node', 'prefixlen' => '128', 'family' => 'inet6' },
            '127.0.0.1' => { 'netmask' => '255.0.0.0', 'family' => 'inet' }
          }
        }
      }
    }
  }

PLUGIN_MAP = {
  'bigswitch' => 'restproxy.ini',
  'brocade' => 'brocade.ini',
  'cisco' => 'cisco_plugins.ini',
  'hyperv' => 'hyperv_neutron_plugin.ini.erb',
  'linuxbridge' => 'linuxbridge_conf.ini',
  'midonet' => 'midonet.ini',
  'metaplugin' => 'metaplugin.ini',
  'ml2' => 'ml2_conf.ini',
  'nec' => 'nec.ini',
  'nicira' => 'nvp.ini',
  'openvswitch' => 'ovs_neutron_plugin.ini',
  'plumgrid' => 'plumgrid.ini',
  'ryu' => 'ryu.ini'
}

shared_context 'neutron-stubs' do
  before do
    allow_any_instance_of(Chef::Recipe).to receive(:rabbit_servers)
      .and_return('1.1.1.1:5672,2.2.2.2:5672')
    allow_any_instance_of(Chef::Recipe).to receive(:config_by_role)
      .with('rabbitmq-server', 'queue').and_return(
        host: 'rabbit-host',
        port: 'rabbit-port'
      )
    allow_any_instance_of(Chef::Recipe).to receive(:config_by_role)
      .with('glance-api', 'glance').and_return []
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'openstack_identity_bootstrap_token')
      .and_return('bootstrap-token')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'neutron_metadata_secret')
      .and_return('metadata-secret')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('db', anything)
      .and_return('neutron')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('service', 'openstack-network')
      .and_return('neutron-pass')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('user', 'guest')
      .and_return('mq-pass')
    allow(Chef::Application).to receive(:fatal!)
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('service', 'openstack-compute')
      .and_return('nova-pass')
    allow_any_instance_of(Chef::Resource::RubyBlock).to receive(:openstack_command_env)
      .with('admin', 'admin')
      .and_return({})
    allow_any_instance_of(Chef::Resource::RubyBlock).to receive(:identity_uuid)
      .with('tenant', 'name', 'service', {}, {})
      .and_return('000-UUID-FROM-CLI')
    allow_any_instance_of(Chef::Resource::RubyBlock).to receive(:network_uuid)
      .with('net-external', 'name', 'public', {})
      .and_return('000-NET-UUID-FROM-CLI')

    stub_command('dpkg -l | grep openvswitch-switch | grep 1.10.2-1').and_return(true)
    stub_command('ovs-vsctl br-exists br-int').and_return(false)
    stub_command('ovs-vsctl br-exists br-tun').and_return(false)
    stub_command('ip link show eth1').and_return(false)
  end
end

shared_examples 'custom template banner displayer' do
  it 'shows the custom banner' do
    node.set['openstack']['network']['custom_template_banner'] = 'custom_template_banner_value'
    expect(chef_run).to render_file(file_name).with_content(/^custom_template_banner_value$/)
  end
end

shared_examples 'common network attributes displayer' do
  %w(debug interface_driver use_namespaces).each do |attr|
    it "displays the #{attr} common attribute" do
      node.set['openstack']['network'][attr] = "network_#{attr}_value"
      expect(chef_run).to render_file(file_name).with_content(/^#{attr} = network_#{attr}_value$/)
    end
  end
end

shared_examples 'dhcp agent template configurator' do
  it_behaves_like 'custom template banner displayer'

  it_behaves_like 'common network attributes displayer'

  it 'displays the dhcp driver attribute' do
    node.set['openstack']['network']['dhcp_driver'] = 'network_dhcp_driver_value'
    expect(chef_run).to render_file(file_name).with_content(/^dhcp_driver = network_dhcp_driver_value$/)
  end

  %w(resync_interval ovs_use_veth enable_isolated_metadata
     enable_metadata_network dnsmasq_lease_max dhcp_delete_namespaces).each do |attr|
    it "displays the #{attr} dhcp attribute" do
      node.set['openstack']['network']['dhcp'][attr] = "network_dhcp_#{attr}_value"
      expect(chef_run).to render_file(file_name).with_content(/^#{attr} = network_dhcp_#{attr}_value$/)
    end
  end

  it 'displays the dhcp_domain attribute' do
    node.set['openstack']['network']['dhcp']['default_domain'] = 'network_dhcp_domain_value'
    expect(chef_run).to render_file(file_name).with_content(/^dhcp_domain = network_dhcp_domain_value$/)
  end
end

shared_examples 'dnsmasq template configurator' do
  it_behaves_like 'custom template banner displayer'

  it 'displays the dhcp-option attribute' do
    node.set['openstack']['network']['dhcp']['dhcp-option'] = 'dhcp-option_value'
    expect(chef_run).to render_file(file_name).with_content(/^dhcp-option=dhcp-option_value$/)
  end

  it 'displays the upstream dns servers setting' do
    node.set['openstack']['network']['dhcp']['upstream_dns_servers'] = %w(server0 server1)
    node['openstack']['network']['dhcp']['upstream_dns_servers'].each do |dns_server|
      expect(chef_run).to render_file(file_name).with_content(/^server=#{dns_server}$/)
    end
  end
end
