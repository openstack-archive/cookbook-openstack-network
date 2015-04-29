# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.linuxbridge.lb_neutron_plugin.LinuxBridgePluginV2'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install linuxbridge agent package when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('openstack-neutron-linuxbridge-agent')
    end

    it 'upgrades linuxbridge agent' do
      expect(chef_run).to upgrade_package('openstack-neutron-linuxbridge-agent')
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(chef_run).to enable_service('openstack-neutron-linuxbridge-agent')
    end
  end
end
