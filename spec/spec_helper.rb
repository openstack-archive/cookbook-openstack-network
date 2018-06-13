# Encoding: utf-8
require 'chefspec'
require 'pry'
require 'chefspec/berkshelf'

ChefSpec::Coverage.start! { add_filter 'openstack-network' }

require 'chef/application'

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
  config.log_level = :fatal
end

REDHAT_OPTS = {
  platform: 'redhat',
  version: '7.4',
}.freeze
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '16.04',
}.freeze
CENTOS_OPTS = {
  platform: 'centos',
  version: '7.4.1708',
}.freeze

shared_context 'neutron-stubs' do
  before do
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
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('user', 'admin')
      .and_return('admin-pass')
    allow_any_instance_of(Chef::Recipe).to receive(:rabbit_transport_url)
      .with('network')
      .and_return('rabbit://guest:mypass@127.0.0.1:5672')
  end
  shared_examples 'custom template banner displayer' do
    it 'shows the custom banner' do
      node.set['openstack']['network']['custom_template_banner'] = 'custom_template_banner_value'
      expect(chef_run).to render_file(file_name).with_content(/^custom_template_banner_value$/)
    end
  end
  shared_examples 'common network attributes displayer' do |plugin|
    it 'displays the interface_driver common attribute' do
      node.set['openstack']["network_#{plugin}"]['conf']['DEFAULT']['interface_driver'] = 'network_interface_driver_value'
      expect(chef_run).to render_file(file_name).with_content(/^interface_driver = network_interface_driver_value$/)
    end
  end

  shared_examples 'dhcp agent template configurator' do
    it_behaves_like 'custom template banner displayer'

    it_behaves_like 'common network attributes displayer', 'dhcp'

    %w(resync_interval ovs_use_veth enable_isolated_metadata
       enable_metadata_network dnsmasq_lease_max dhcp_delete_namespaces).each do |attr|
      it "displays the #{attr} dhcp attribute" do
        node.set['openstack']['network_dhcp']['conf']['DEFAULT'][attr] = "network_dhcp_#{attr}_value"
        expect(chef_run).to render_file(file_name).with_content(/^#{attr} = network_dhcp_#{attr}_value$/)
      end
    end
  end
end
