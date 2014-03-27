# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::hyperv' do
  describe 'redhat' do
    let(:runner) { ChefSpec::Runner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.hyperv.hyperv_neutron_plugin.HyperVNeutronPlugin'
      node.set['openstack']['network']['core_plugin_map'] = { 'hypervneutronplugin' => 'hyperv' }
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    describe 'hyperv_neutron_plugin.ini.erb' do
      let(:file) { chef_run.template('/etc/neutron/plugins/hyperv/hyperv_neutron_plugin.ini.erb') }

      it 'uses default firewall_driver' do
        expect(chef_run).to render_file(file.name).with_content(
          /^firewall_driver = neutron.plugins.hyperv.agent.security_groups_driver.HyperVSecurityGroupsDriver/)
      end

    end
  end
end
