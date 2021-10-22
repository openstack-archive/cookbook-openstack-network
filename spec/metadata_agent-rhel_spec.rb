require_relative 'spec_helper'

describe 'openstack-network::metadata_agent' do
  ALL_RHEL.each do |p|
    context "redhat #{p[:version]}" do
      let(:runner) { ChefSpec::SoloRunner.new(p) }
      let(:node) { runner.node }
      cached(:chef_run) do
        node.override['openstack']['compute']['network']['service_type'] = 'neutron'
        runner.converge(described_recipe)
      end

      include_context 'neutron-stubs'

      it do
        expect(chef_run).to enable_service('neutron-metadata-agent').with(
          service_name: 'neutron-metadata-agent',
          supports: {
            status: true,
            restart: true,
          }
        )
      end

      it do
        expect(chef_run).to start_service('neutron-metadata-agent')
      end
    end
  end
end
