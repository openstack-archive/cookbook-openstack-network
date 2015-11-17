# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-network::nuage' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.nuage.plugin.NuagePlugin'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'upgrades nuage neutron plugin' do
      allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-network::server').and_return(true)
      allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-compute::compute').and_return(false)
      expect(chef_run).to upgrade_package('nuage-openstack-neutron')
      expect(chef_run).to upgrade_package('nuage-openstack-neutronclient')
      expect(chef_run).to upgrade_package('nuagenetlib')
    end
  end
end
