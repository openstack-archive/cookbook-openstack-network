# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::vpnaas' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      node.override['openstack']['network']['enable_vpn'] = true
      stub_command('ovs-vsctl br-exists br-ex').and_return(false)
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'upgrades neutron vpn packages' do
      %w(iproute openstack-neutron-vpnaas strongswan).each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end
  end
end
