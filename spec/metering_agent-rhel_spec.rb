require_relative 'spec_helper'

describe 'openstack-network::metering_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to upgrade_package('neutron-metering-agent')
    end

    it do
      expect(chef_run).to enable_service('neutron-metering-agent').with(
        service_name: 'neutron-metering-agent',
        supports: {
          status: true,
          restart: true,
        }
      )
    end
  end
end
