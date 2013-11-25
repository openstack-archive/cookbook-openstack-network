require_relative "spec_helper"

describe 'openstack-network::openvswitch' do
  describe "opensuse" do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::OPENSUSE_OPTS do |n|
        n.set["chef_client"]["splay"] = 300
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
      @node = @chef_run.node
      @chef_run.converge "openstack-network::openvswitch"
    end

    it "does not install openvswitch package when nova networking" do
      chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      chef_run.converge "openstack-network::openvswitch"
      expect(chef_run).to_not install_package "openvswitch-switch"
    end

    it "installs the openvswitch package" do
      expect(@chef_run).to install_package "openvswitch-switch"
    end

    it "installs the openvswitch-agent package" do
      expect(@chef_run).to install_package "openstack-neutron-openvswitch-agent"
    end

    it "starts the openvswitch-switch service" do
      expect(@chef_run).to set_service_to_start_on_boot "openvswitch-switch"
    end
  end
end
