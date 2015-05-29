# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::db_migration' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    it 'uses db upgrade head with default timeout for neutron-server' do
      expect(chef_run).to run_bash('migrate network database').with(
        code: /upgrade head/,
        timeout: 3600
      )
    end

    it 'uses db upgrade head with timeout override for neutron-server' do
      node.set['openstack']['network']['dbsync_timeout'] = 1234
      expect(chef_run).to run_bash('migrate network database').with(
        code: /upgrade head/,
        timeout: 1234
      )
    end

    it 'uses db upgrade head when vpnaas is enabled' do
      node.set['openstack']['network']['enable_vpn'] = true
      migrate_cmd = %r{neutron-db-manage --service vpnaas --config-file /etc/neutron/neutron.conf|
        --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head}
      expect(chef_run).to run_bash('migrate vpnaas database').with(code: migrate_cmd)
    end

    it 'does not use db upgrade head when vpnaas is not enabled' do
      migrate_cmd = %r{neutron-db-manage --service vpnaas --config-file /etc/neutron/neutron.conf|
        --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head}
      expect(chef_run).not_to run_bash('migrate vpnaas database').with(code: migrate_cmd)
    end

    it 'uses db upgrade head when fwaas is enabled' do
      node.set['openstack']['network']['fwaas']['enabled'] = 'True'
      migrate_cmd = %r{neutron-db-manage --service fwaas --config-file /etc/neutron/neutron.conf|
        --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head}
      expect(chef_run).to run_bash('migrate fwaas database').with(code: migrate_cmd)
    end

    it 'does not use db upgrade head when fwaas is not enabled' do
      migrate_cmd = %r{neutron-db-manage --service fwaas --config-file /etc/neutron/neutron.conf|
        --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head}
      expect(chef_run).not_to run_bash('migrate fwaas database').with(code: migrate_cmd)
    end

    it 'uses db upgrade head when lbaas is enabled' do
      node.set['openstack']['network']['lbaas']['enabled'] = 'True'
      migrate_cmd = %r{neutron-db-manage --service lbaas --config-file /etc/neutron/neutron.conf|
        --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head}
      expect(chef_run).to run_bash('migrate lbaas database').with(code: migrate_cmd)
    end

    it 'does not use db upgrade head when lbaas is not enabled' do
      migrate_cmd = %r{neutron-db-manage --service lbaas --config-file /etc/neutron/neutron.conf|
        --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head}
      expect(chef_run).not_to run_bash('migrate lbaas database').with(code: migrate_cmd)
    end
  end
end
