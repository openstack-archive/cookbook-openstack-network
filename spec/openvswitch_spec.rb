require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do

  describe "ubuntu" do

    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new(::UBUNTU_OPTS) do |n|
        n.automatic_attrs["kernel"]["release"] = "1.2.3"
      end
      @chef_run.converge "openstack-network::openvswitch"
    end

    it "installs openvswitch switch" do
      expect(@chef_run).to install_package "openvswitch-switch"
    end
    it "installs openvswitch datapath dkms" do
      expect(@chef_run).to install_package "openvswitch-datapath-dkms"
    end
    it "installs linux bridge utils" do
      expect(@chef_run).to install_package "bridge-utils"
    end
    it "installs linux kernel headers" do
      expect(@chef_run).to install_package "linux-headers-1.2.3"
    end
    it "sets the openvswitch service to start on boot" do
      expect(@chef_run).to set_service_to_start_on_boot 'openvswitch-switch'
    end

  end

end
