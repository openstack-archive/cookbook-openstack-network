require_relative 'spec_helper'

describe 'openstack-network::server' do
  ALL_RHEL.each do |p|
    context "redhat #{p[:version]}" do
      let(:runner) { ChefSpec::SoloRunner.new(p) }
      let(:node) { runner.node }
      cached(:chef_run) do
        node.override['openstack']['compute']['network']['service_type'] = 'neutron'
        node.override['openstack']['network']['plugins']['ml2']['path'] = '/etc/neutron/plugins/ml2'
        node.override['openstack']['network']['plugins']['ml2']['filename'] = 'openvswitch_agent.ini'
        runner.converge(described_recipe)
      end
      include_context 'neutron-stubs'

      it do
        expect(chef_run).to upgrade_package %w(ebtables iproute openstack-neutron openstack-neutron-ml2)
      end

      it do
        expect(chef_run).to enable_service 'neutron-server'
      end

      it 'does not upgrade openvswitch package' do
        expect(chef_run).not_to upgrade_package 'openvswitch'
        expect(chef_run).not_to enable_service 'neutron-openvswitch-agent'
      end
    end
  end
end
