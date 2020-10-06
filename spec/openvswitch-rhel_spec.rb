require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    it do
      expect(chef_run).to upgrade_package 'openvswitch'
    end

    it do
      expect(chef_run).to enable_service('neutron-openvswitch-switch').with(
        service_name: 'openvswitch',
        supports: {
          status: true,
          restart: true,
        }
      )
    end
  end
end
