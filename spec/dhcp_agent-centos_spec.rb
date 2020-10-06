require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'centos' do
    let(:runner) { ChefSpec::SoloRunner.new(CENTOS_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    let(:file_cache_path) { Chef::Config[:file_cache_path] }

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to upgrade_package(%w(openstack-neutron iproute))
    end

    it do
      expect(chef_run).to upgrade_rpm_package('dnsmasq')
    end
  end
end
