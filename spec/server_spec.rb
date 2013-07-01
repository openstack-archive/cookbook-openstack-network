require_relative 'spec_helper'

describe 'openstack-network::server' do

  describe "ubuntu" do

    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      @node = @chef_run.node

      # mock out an interface on the storage node
      @node.set["network"] = MOCK_NODE_NETWORK_DATA['network']

      @chef_run.converge "openstack-network::server"
    end

    it "installs quantum packages" do
      expect(@chef_run).to install_package "quantum-server"
    end

    it "installs metadata packages" do
      expect(@chef_run).to install_package "quantum-metadata-agent"
    end

    it "starts metadata service" do
      expect(@chef_run).to enable_service "quantum-metadata-agent"
    end
  end
end
