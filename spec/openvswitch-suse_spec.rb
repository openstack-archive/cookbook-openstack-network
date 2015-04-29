# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install openvswitch package when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package 'openvswitch-switch'
    end

    it 'upgrades the openvswitch package' do
      expect(chef_run).to upgrade_package 'openvswitch-switch'
    end

    it 'upgrades the openvswitch-agent package' do
      expect(chef_run).to upgrade_package 'openstack-neutron-openvswitch-agent'
    end

    it 'starts the openvswitch-switch service' do
      expect(chef_run).to enable_service 'openvswitch-switch'
    end
  end
end
