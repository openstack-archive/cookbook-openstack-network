require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do

  describe "ubuntu" do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
      @chef_run.converge "openstack-network::dhcp_agent"
    end

    it "does not include recipe openstack-network::comon when nova networking" do
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      @chef_run.converge "openstack-network::dhcp_agent"
      expect(@chef_run).to_not include_recipe  "openstack-network::common"
    end

    # since our mocked version of ubuntu is precise, our compile
    # utilities should be installed to build dnsmasq
    it "installs dnsmasq build dependencies" do
      [ "build-essential", "pkg-config", "libidn11-dev", "libdbus-1-dev", "libnetfilter-conntrack-dev", "gettext" ].each do |pkg|
        expect(@chef_run).to install_package pkg
      end
    end

    it "installs quamtum dhcp package" do
      expect(@chef_run).to install_package "neutron-dhcp-agent"
    end

    it "installs plugin packages" do
      expect(@chef_run).to install_package "neutron-plugin-openvswitch"
    end

    it "starts the dhcp agent on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "neutron-dhcp-agent"
    end

    describe "/etc/neutron/plugins" do
      before do
        @file = @chef_run.directory "/etc/neutron/plugins"
      end
      it "has proper owner" do
        expect(@file).to be_owned_by "neutron", "neutron"
      end
      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "700"
      end
    end

    describe "/etc/neutron/dhcp_agent.ini" do
      before do
        @file = @chef_run.template "/etc/neutron/dhcp_agent.ini"
      end
      it "has proper owner" do
        expect(@file).to be_owned_by "neutron", "neutron"
      end
      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end
      it "uses ovs driver" do
        expect(@chef_run).to create_file_with_content @file.name,
          "interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver"
      end
      it "uses namespaces" do
        expect(@chef_run).to create_file_with_content @file.name,
          "use_namespaces = True"
      end
      it "checks dhcp domain" do
        expect(@chef_run).to create_file_with_content @file.name,
          /^dhcp_domain = openstacklocal$/
      end
    end

    describe "/etc/neutron/dnsmasq.conf" do
      before do
        @file = @chef_run.template "/etc/neutron/dnsmasq.conf"
      end
      it "has proper owner" do
        expect(@file).to be_owned_by "neutron", "neutron"
      end
      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end
      it "overrides dhcp options" do
        expect(@chef_run).to create_file_with_content @file.name,
          "dhcp-option=26,1454"
      end
      it "checks upstream resolvers" do
        expect(@chef_run).to create_file_with_content @file.name,
          /^server=209.244.0.3$/
        expect(@chef_run).to create_file_with_content @file.name,
          /^server=8.8.8.8$/
      end
    end
  end
end
