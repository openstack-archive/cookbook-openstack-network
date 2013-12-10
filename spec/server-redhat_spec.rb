require_relative "spec_helper"

describe 'openstack-network::server' do
  describe "redhat" do
    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::REDHAT_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "quantum"
      end
      @node = @chef_run.node
      @chef_run.converge "openstack-network::server"
    end

    it "does not install openstack-quantum when nova networking" do
      chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      chef_run.converge "openstack-network::server"
      expect(chef_run).to_not install_package "openstack-quantum"
    end

    it "installs openstack-quantum packages" do
      expect(@chef_run).to install_package "openstack-quantum"
    end

    it "enables openstack-quantum server service" do
      expect(@chef_run).to enable_service "quantum-server"
    end

    it "does not install openvswitch package" do
      opts = ::REDHAT_OPTS.merge(:evaluate_guards => true)
      chef_run = ::ChefSpec::ChefRunner.new opts do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "quantum"
      end
      chef_run.converge "openstack-network::server"
      expect(chef_run).not_to install_package "openvswitch"
      expect(chef_run).not_to enable_service "openstack-quantum-openvswitch-agent"
    end
  end
end
