# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
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

      expect(chef_run).to_not upgrade_package('openstack-neutron-linuxbridge')
    end

    it 'upgrades linuxbridge agent' do
      expect(chef_run).to upgrade_package('openstack-neutron-linuxbridge')
    end

    it 'creates the /etc/neutron/plugins/linuxbridge agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/linuxbridge').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0700
      )
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(chef_run).to enable_service('neutron-linuxbridge-agent')
    end

    describe '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini') }

      it 'creates linuxbridge_conf.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it 'create plugin.ini symlink' do
        expect(chef_run).to create_link('/etc/neutron/plugin.ini').with(
          to: file.name,
          owner: 'neutron',
          group: 'neutron'
        )
      end
    end
  end
end
