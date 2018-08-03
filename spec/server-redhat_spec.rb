# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end
    before do
      node.override['openstack']['network']['plugins']['ml2']['path'] = '/etc/neutron/plugins/ml2'
      node.override['openstack']['network']['plugins']['ml2']['filename'] = 'openvswitch_agent.ini'
    end
    include_context 'neutron-stubs'

    it 'upgrades openstack-neutron packages' do
      expect(chef_run).to upgrade_package 'openstack-neutron'
    end

    it 'enables openstack-neutron server service' do
      expect(chef_run).to enable_service 'neutron-server'
    end

    it 'does not upgrade openvswitch package' do
      expect(chef_run).not_to upgrade_package 'openvswitch'
      expect(chef_run).not_to enable_service 'neutron-openvswitch-agent'
    end
  end
end
