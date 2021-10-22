require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  ALL_RHEL.each do |p|
    context "redhat #{p[:version]}" do
      describe 'redhat' do
        let(:runner) { ChefSpec::SoloRunner.new(p) }
        let(:node) { runner.node }
        cached(:chef_run) do
          runner.converge(described_recipe)
        end

        it do
          expect(chef_run).to upgrade_package 'openvswitch'
        end

        it do
          expect(chef_run).to enable_service('neutron-openvswitch-switch').with(
            service_name: 'openvswitch',
            supports: {
              status: true,
              restart: true,
            }
          )
        end
      end
    end
  end
end
