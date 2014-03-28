# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'redhat' do
    let(:runner) { ChefSpec::Runner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install openstack-neutron when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not install_package 'openstack-neutron'
    end

    it 'installs openstack-neutron packages' do
      expect(chef_run).to install_package 'openstack-neutron'
    end

    it 'enables openstack-neutron server service' do
      expect(chef_run).to enable_service 'neutron-server'
    end

    it 'does not install openvswitch package' do
      expect(chef_run).not_to install_package 'openvswitch'
      expect(chef_run).not_to enable_service 'neutron-openvswitch-agent'
    end
  end
end
