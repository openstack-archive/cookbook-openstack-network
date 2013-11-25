require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do

  describe "redhat" do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::REDHAT_OPTS do |n|
        n.set["openstack"]["network"]["interface_driver"] = "neutron.agent.linux.interface.BridgeInterfaceDriver"
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
      @chef_run.converge "openstack-network::linuxbridge"
    end

    it "does not install linuxbridge agent package when nova networking" do
      chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      chef_run.converge "openstack-network::linuxbridge"
      expect(chef_run).to_not install_package "openstack-neutron-linuxbridge"
    end

    it "installs linuxbridge agent" do
      expect(@chef_run).to install_package "openstack-neutron-linuxbridge"
    end

    it "sets the linuxbridge service to start on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "neutron-linuxbridge-agent"
    end

  end
end
