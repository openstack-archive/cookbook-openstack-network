require_relative "spec_helper"

describe 'openstack-network::server' do
  describe "opensuse" do
    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::OPENSUSE_OPTS
      @node = @chef_run.node

      @chef_run.converge "openstack-network::server"
    end

    it "installs openstack-quantum packages" do
      expect(@chef_run).to install_package "openstack-quantum"
    end

    it "enables openstack-quantum service" do
      expect(@chef_run).to enable_service "openstack-quantum"
    end

    it "does not install openvswitch package" do
      opts = ::OPENSUSE_OPTS.merge(:evaluate_guards => true)
      chef_run = ::ChefSpec::ChefRunner.new opts
      chef_run.converge "openstack-network::server"

      expect(chef_run).not_to install_package "openstack-quantum-openvswitch"
    end
  end
end
