require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do

  describe "ubuntu" do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
        n.set["openstack"]["network"]["interface_driver"] = "neutron.agent.linux.interface.BridgeInterfaceDriver"
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
        n.set["openstack"]["db"]["network"]["db_name"] = "neutron"
      end
      @chef_run.converge "openstack-network::linuxbridge"
    end

    it "does not install linuxbridge agent package when nova networking" do
      chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      chef_run.converge "openstack-network::linuxbridge"
      expect(chef_run).to_not install_package "neutron-plugin-linuxbridge-agent"
    end

    it "installs linuxbridge agent" do
      expect(@chef_run).to install_package "neutron-plugin-linuxbridge-agent"
    end

    it "sets the linuxbridge service to start on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "neutron-plugin-linuxbridge-agent"
    end

    describe "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini" do
      before do
        @file = @chef_run.template(
          "/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini")
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "neutron", "neutron"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "has a correct sql_connection value" do
        expect(@chef_run).to create_file_with_content(
          @file.name, "mysql://neutron:neutron-pass@127.0.0.1:3306/neutron")
      end

      it "sets sqlalchemy attributes" do
        expect(@chef_run).to create_file_with_content @file.name,
          "sql_dbpool_enable = False",
          "sql_min_pool_size = 1",
          "sql_max_pool_size = 10",
          "sql_idle_timeout = 3600"
      end
    end
  end
end
