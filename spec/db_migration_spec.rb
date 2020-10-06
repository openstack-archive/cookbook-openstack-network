require_relative 'spec_helper'

describe 'openstack-network::db_migration' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    it 'uses db upgrade head with default timeout for neutron-server' do
      expect(chef_run).to run_execute('migrate network database').with(
        command: "neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head\n",
        timeout: 3600
      )
    end

    context 'uses db upgrade head with timeout override for neutron-server' do
      cached(:chef_run) do
        node.override['openstack']['network']['dbsync_timeout'] = 1234
        runner.converge(described_recipe)
      end
      it do
        expect(chef_run).to run_execute('migrate network database').with(
          command: "neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head\n",
          timeout: 1234
        )
      end
    end
  end
end
