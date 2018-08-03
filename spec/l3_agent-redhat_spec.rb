# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      stub_command('ovs-vsctl br-exists br-ex').and_return(false)
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'upgrades neutron ml2_ovs packages' do
      %w(openstack-neutron iproute radvd keepalived).each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end
  end
end
