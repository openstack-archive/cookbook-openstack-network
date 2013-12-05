require_relative 'spec_helper'

describe "openstack-network::common" do
  describe "redhat" do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
      @chef_run.converge "openstack-network::common"
    end

    it "installs mysql python packages by default" do
      expect(@chef_run).to install_package "MySQL-python"
    end

    it "installs db2 python packages if explicitly told" do
      @chef_run.node.set["openstack"]["db"]["network"]["db_type"] = "db2"
      @chef_run.converge "openstack-network::common"

      ["db2-odbc", "python-ibm-db", "python-ibm-db-sa"].each do |pkg|
        expect(@chef_run).to install_package pkg
      end
    end
  end
end
