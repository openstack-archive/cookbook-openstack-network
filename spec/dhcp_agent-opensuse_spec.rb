require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do

  describe "opensuse" do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::OPENSUSE_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
      @chef_run.converge "openstack-network::dhcp_agent"
    end

    it "does not install openstack-neutron-dhcp-agent when nova networking" do
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      @chef_run.converge "openstack-network::dhcp_agent"
      expect(@chef_run).to_not install_package "openstack-neutron-dhcp-agent"
    end

    it "installs quamtum dhcp package" do
      expect(@chef_run).to install_package "openstack-neutron-dhcp-agent"
    end

    it "installs plugin packages" do
      expect(@chef_run).not_to install_package(/openvswitch/)
      expect(@chef_run).not_to install_package(/plugin/)
    end

    it "starts the dhcp agent on boot" do
      expect(@chef_run).to(
        set_service_to_start_on_boot "openstack-neutron-dhcp-agent")
    end

    it "/etc/neutron/dhcp_agent.ini has the proper owner" do
      expect(@chef_run.template "/etc/neutron/dhcp_agent.ini").to(
        be_owned_by "openstack-neutron", "openstack-neutron")
    end

    it "/etc/neutron/dnsmasq.conf has the proper owner" do
      expect(@chef_run.template "/etc/neutron/dnsmasq.conf").to(
        be_owned_by "openstack-neutron", "openstack-neutron")
    end
  end
end
