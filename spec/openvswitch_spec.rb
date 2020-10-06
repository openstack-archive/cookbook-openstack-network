require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe, 'openstack-network::plugin_config')
    end

    it do
      expect(chef_run).to upgrade_package %w(openvswitch-switch bridge-utils)
    end

    it do
      expect(chef_run).to enable_service('neutron-openvswitch-switch').with(
        service_name: 'openvswitch-switch',
        supports: {
          status: true,
          restart: true,
        }
      )
    end

    it do
      expect(chef_run).to start_service 'neutron-openvswitch-switch'
    end

    it do
      expect(chef_run.service('neutron-openvswitch-switch')).to \
        subscribe_to('template[/etc/neutron/plugins/ml2/openvswitch_agent.ini]').on(:restart)
    end
  end
end
