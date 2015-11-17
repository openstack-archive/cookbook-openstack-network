# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::ml2_openvswitch' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2'

      runner.converge(described_recipe)
    end
    before do
      node.set['openstack']['network']['plugins']['openvswitch']['path'] = '/etc/neutron/plugins/openvswitch'
      node.set['openstack']['network']['plugins']['openvswitch']['filename'] = 'openvswitch_plugin.ini'
    end
    include_context 'neutron-stubs'

    it 'upgrades neutron ml2_ovs packages' do
      %w(openstack-neutron-openvswitch openvswitch).each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end
    it_behaves_like 'plugin_config builder', 'openvswitch'
  end
end
