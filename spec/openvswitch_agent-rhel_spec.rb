require_relative 'spec_helper'

describe 'openstack-network::openvswitch_agent' do
  ALL_RHEL.each do |p|
    context "redhat #{p[:version]}" do
      let(:runner) { ChefSpec::SoloRunner.new(p) }
      let(:node) { runner.node }
      cached(:chef_run) do
        node.override['openstack']['network']['openvswitch']['integration_bridge'] = 'br-int'
        runner.converge(described_recipe)
      end

      include_context 'neutron-stubs'

      before do
        stub_command('ovs-vsctl --may-exist add-br br-int')
      end

      it do
        expect(chef_run).to upgrade_package %w(openstack-neutron-openvswitch iproute)
      end

      it do
        expect(chef_run).to enable_service('neutron-openvswitch-agent').with(
          service_name: 'neutron-openvswitch-agent',
          supports: {
            status: true,
            restart: true,
          }
        )
      end
    end
  end
end
