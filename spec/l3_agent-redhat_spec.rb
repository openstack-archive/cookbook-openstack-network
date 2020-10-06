require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      stub_command('ovs-vsctl br-exists br-ex').and_return(false)
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    pkgs =
      %w(
        iproute
        keepalived
        openstack-neutron
        radvd
      )
    it do
      expect(chef_run).to upgrade_package(pkgs)
    end
  end
end
