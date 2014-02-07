# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do

  describe 'suse' do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::SUSE_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::dhcp_agent'
    end

    it 'does not install openstack-neutron-dhcp-agent when nova networking' do
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      @chef_run.converge 'openstack-network::dhcp_agent'
      expect(@chef_run).to_not install_package 'openstack-neutron-dhcp-agent'
    end

    it 'installs quamtum dhcp package' do
      expect(@chef_run).to install_package 'openstack-neutron-dhcp-agent'
    end

    it 'installs plugin packages' do
      expect(@chef_run).not_to install_package(/openvswitch/)
      expect(@chef_run).not_to install_package(/plugin/)
    end

    it 'starts the dhcp agent on boot' do
      expect(@chef_run).to(
        enable_service 'openstack-neutron-dhcp-agent')
    end

    it '/etc/neutron/dhcp_agent.ini has the proper owner' do
      file = @chef_run.template '/etc/neutron/dhcp_agent.ini'
      expect(file.owner).to eq('openstack-neutron')
      expect(file.group).to eq('openstack-neutron')
    end

    it '/etc/neutron/dnsmasq.conf has the proper owner' do
      file = @chef_run.template '/etc/neutron/dnsmasq.conf'
      expect(file.owner).to eq('openstack-neutron')
      expect(file.group).to eq('openstack-neutron')
    end
  end
end
