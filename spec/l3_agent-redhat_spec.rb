# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    ['openstack-neutron', 'iproute', 'radvd', 'openstack-neutron-fwaas', 'keepalived'].each do |pack|
      it "upgrades #{pack} package" do
        expect(chef_run).to upgrade_package(pack)
      end
    end
    it 'upgrades neutron fwaas package' do
      expect(chef_run).to upgrade_package('openstack-neutron-fwaas')
    end
  end
end
