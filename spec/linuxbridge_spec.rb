# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
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

      expect(chef_run).to_not upgrade_package('neutron-plugin-linuxbridge-agent')
    end

    it 'upgrades linuxbridge agent' do
      expect(chef_run).to upgrade_package('neutron-plugin-linuxbridge-agent')
    end

    it 'creates the /etc/neutron/plugins/linuxbridge agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/linuxbridge').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0700
      )
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(chef_run).to enable_service('neutron-plugin-linuxbridge-agent')
    end

    it 'subscribes the linuxbridge agent service to neutron.conf' do
      expect(chef_run.service('neutron-plugin-linuxbridge-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end
  end
end
