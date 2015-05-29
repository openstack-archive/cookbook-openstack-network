# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::vpn_agent' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['enable_vpn'] = true
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'upgrades neutron vpn packages' do
      expect(chef_run).to upgrade_package('openstack-neutron-vpnaas')
      expect(chef_run).to upgrade_package('iproute')
    end
  end
end
