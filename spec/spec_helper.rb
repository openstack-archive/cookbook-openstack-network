# Encoding: utf-8
require 'chefspec'
require 'chefspec/berkshelf'

ChefSpec::Coverage.start! { add_filter 'openstack-network' }

require 'chef/application'

LOG_LEVEL = :fatal
SUSE_OPTS = {
  platform: 'suse',
  version: '11.03',
  log_level: LOG_LEVEL
}
REDHAT_OPTS = {
    platform: 'redhat',
    version: '6.3',
    log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
    platform: 'ubuntu',
    version: '12.04',
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

shared_context 'neutron-stubs' do
  before do
    Chef::Recipe.any_instance.stub(:rabbit_servers)
      .and_return('1.1.1.1:5672,2.2.2.2:5672')
    Chef::Recipe.any_instance.stub(:config_by_role)
      .with('rabbitmq-server', 'queue').and_return(
        host: 'rabbit-host',
        port: 'rabbit-port'
      )
    Chef::Recipe.any_instance.stub(:config_by_role)
      .with('glance-api', 'glance').and_return []
    Chef::Recipe.any_instance.stub(:secret)
      .with('secrets', 'openstack_identity_bootstrap_token')
      .and_return('bootstrap-token')
    Chef::Recipe.any_instance.stub(:secret)
      .with('secrets', 'neutron_metadata_secret')
      .and_return('metadata-secret')
    Chef::Recipe.any_instance.stub(:get_password)
      .with('db', anything)
      .and_return('neutron')
    Chef::Recipe.any_instance.stub(:get_password)
      .with('service', 'openstack-network')
      .and_return('neutron-pass')
    Chef::Recipe.any_instance.stub(:get_password)
      .with('user', 'guest')
      .and_return('mq-pass')
    Chef::Application.stub(:fatal!)
    Chef::Recipe.any_instance.stub(:get_password)
      .with('service', 'openstack-compute')
      .and_return('nova-pass')
    Chef::Resource::RubyBlock.any_instance.stub(:openstack_command_env)
      .with('admin', 'admin')
      .and_return({})
    Chef::Resource::RubyBlock.any_instance.stub(:identity_uuid)
      .with('tenant', 'name', 'service', {})
      .and_return('000-UUID-FROM-CLI')

    stub_command('dpkg -l | grep openvswitch-switch | grep 1.10.2-1').and_return(true)
    stub_command('ovs-vsctl br-exists br-int').and_return(false)
    stub_command('ovs-vsctl br-exists br-tun').and_return(false)
    stub_command('ip link show eth1').and_return(false)
  end
end
