require_relative 'spec_helper'

describe "openstack-network::common" do
  describe "ubuntu" do
    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "quantum"
      end
      @chef_run.converge "openstack-network::common"
    end

    it "does not install python-quantumclient when nova networking" do
      chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      chef_run.converge "openstack-network::common"
      expect(chef_run).to_not install_package "python-quantumclient"
    end

    it "upgrades python quantumclient" do
      expect(@chef_run).to upgrade_package "python-quantumclient"
    end

    it "upgrades python pyparsing" do
      expect(@chef_run).to upgrade_package "python-pyparsing"
    end
  end
end
