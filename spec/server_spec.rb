require_relative 'spec_helper'

describe 'openstack-network::server' do
  before do
    neutron_stubs
    @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
      n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      n.set["openstack"]["mq"]["host"] = "127.0.0.1"
      n.set["chef_client"]["splay"] = 300
      n.set["openstack"]["network"]["quota"]["driver"] = "my.quota.Driver"
    end
    @chef_run.converge "openstack-network::server"
  end

  it "does not install neutron-server when nova networking" do
    chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
    chef_run.converge "openstack-network::server"
    expect(chef_run).to_not install_package "neutron-server"
  end

  describe "package and services" do

    it "installs neutron packages" do
      expect(@chef_run).to install_package "neutron-server"
    end

    it "starts server service" do
      expect(@chef_run).to enable_service "neutron-server"
    end

    it "does not install openvswitch package or the agent" do
      expect(@chef_run).not_to install_package "openvswitch"
      expect(@chef_run).not_to install_package "neutron-plugin-openvswitch-agent"
      expect(@chef_run).not_to enable_service "neutron-plugin-openvswitch-agent"
    end

  end

  describe "api-paste.ini" do

    before do
     @file = @chef_run.template "/etc/neutron/api-paste.ini"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "neutron", "neutron"
    end

    it "has proper modes" do
     expect(sprintf("%o", @file.mode)).to eq "640"
    end

    it "has neutron pass" do
      expect(@chef_run).to create_file_with_content @file.name,
        "admin_password = neutron-pass"
    end

    it "has auth_uri" do
      expect(@chef_run).to create_file_with_content @file.name,
      "auth_uri = http://127.0.0.1:5000/v2.0"
    end

    it "has auth_host" do
      expect(@chef_run).to create_file_with_content @file.name,
      "auth_host = 127.0.0.1"
    end

    it "has auth_port" do
      expect(@chef_run).to create_file_with_content @file.name,
      "auth_port = 35357"
    end

    it "has auth_protocol" do
      expect(@chef_run).to create_file_with_content @file.name,
      "auth_protocol = http"
    end
  end

  it "should create neutron-ha-tool.py script" do
    expect(@chef_run).to create_cookbook_file "/usr/local/bin/neutron-ha-tool.py"
  end

  describe "neutron.conf" do

    before do
     @file = @chef_run.template "/etc/neutron/neutron.conf"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "neutron", "neutron"
    end

    it "has proper modes" do
     expect(sprintf("%o", @file.mode)).to eq "644"
    end

    it "it sets agent_down_time correctly" do
      expect(@chef_run).to create_file_with_content @file.name,
        'agent_down_time = 15'
    end

    it "it sets agent report interval correctly" do
      expect(@chef_run).to create_file_with_content @file.name,
        'report_interval = 4'
    end

    it "it sets root_helper" do
      expect(@chef_run).to create_file_with_content @file.name,
        'root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"'
    end

    it "binds to appropriate api ip" do
      expect(@chef_run).to create_file_with_content @file.name,
        "bind_host = 127.0.0.1"
    end

    it "binds to appropriate api port" do
      expect(@chef_run).to create_file_with_content @file.name,
        "bind_port = 9696"
    end

    it "has appropriate auth host for agents"  do
      expect(@chef_run).to create_file_with_content @file.name,
        "auth_host = 127.0.0.1"
    end

    it "has appropriate auth port for agents"  do
      expect(@chef_run).to create_file_with_content @file.name,
        "auth_port = 5000"
    end

    it "has appropriate admin password for agents"  do
      expect(@chef_run).to create_file_with_content @file.name,
        "admin_password = neutron-pass"
    end

    it "has rabbit_host" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_host=127.0.0.1"
    end

    it "does not have rabbit_hosts" do
      expect(@chef_run).not_to create_file_with_content @file.name,
        "rabbit_hosts="
    end

    it "does not have rabbit_ha_queues" do
      expect(@chef_run).not_to create_file_with_content @file.name,
        "rabbit_ha_queues="
    end

    it "has rabbit_port" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_port=5672"
    end

    it "has rabbit_userid" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_userid=guest"
    end

    it "has rabbit_password" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_password=rabbit-pass"
    end

    it "has rabbit_virtual_host" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_virtual_host=/"
    end

    describe "qpid" do
      before do
        @file = @chef_run.template "/etc/neutron/neutron.conf"
        @chef_run.node.set['openstack']['network']['mq']['service_type'] = "qpid"
      end

      it "has qpid_hostname" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_hostname=127.0.0.1"
      end

      it "has qpid_port" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_port=5672"
      end

      it "has qpid_username" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_username="
      end

      it "has qpid_password" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_password="
      end

      it "has qpid_sasl_mechanisms" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_sasl_mechanisms="
      end

      it "has qpid_reconnect" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_reconnect=true"
      end

      it "has qpid_reconnect_timeout" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_reconnect_timeout=0"
      end

      it "has qpid_reconnect_limit" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_reconnect_limit=0"
      end

      it "has qpid_reconnect_interval_min" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_reconnect_interval_min=0"
      end

      it "has qpid_reconnect_interval_max" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_reconnect_interval_max=0"
      end

      it "has qpid_reconnect_interval" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_reconnect_interval=0"
      end

      it "has qpid_heartbeat" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_heartbeat=60"
      end

      it "has qpid_protocol" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_protocol=tcp"
      end

      it "has qpid_tcp_nodelay" do
        expect(@chef_run).to create_file_with_content @file.name,
          "qpid_tcp_nodelay=true"
      end
    end

    it "it does not allow overlapping ips by default" do
      expect(@chef_run).to create_file_with_content @file.name,
        "allow_overlapping_ips = False"
    end

    it "it has correct default scheduler classes" do
      expect(@chef_run).to create_file_with_content @file.name,
        "network_scheduler_driver = neutron.scheduler.dhcp_agent_scheduler.ChanceScheduler"
      expect(@chef_run).to create_file_with_content @file.name,
        "router_scheduler_driver = neutron.scheduler.l3_agent_scheduler.ChanceScheduler"
    end

    it "has the overridable default quota values" do
      expect(@chef_run).to create_file_with_content @file.name,
        /^quota_items = network,subnet,port/
      expect(@chef_run).to create_file_with_content @file.name,
        /^default_quota = -1/
      expect(@chef_run).to create_file_with_content @file.name,
        /^quota_network = 10/
      expect(@chef_run).to create_file_with_content @file.name,
        /^quota_subnet = 10/
      expect(@chef_run).to create_file_with_content @file.name,
        /^quota_port = 50/
      expect(@chef_run).to create_file_with_content @file.name,
        /^quota_security_group = 10/
      expect(@chef_run).to create_file_with_content @file.name,
        /^quota_security_group_rule = 100/
    end

    it "writes the quota driver properly" do
      expect(@chef_run).to create_file_with_content @file.name,
        "quota_driver = my.quota.Driver"
    end

    describe "neutron.conf with rabbit ha" do

      before do
        @chef_run = ::ChefSpec::ChefRunner.new(::UBUNTU_OPTS) do |n|
          n.set["openstack"]["network"]["rabbit"]["ha"] = true
          n.set["chef_client"]["splay"] = 300
          n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
        end
        @chef_run.converge "openstack-network::server"
      end

      it "has rabbit_hosts" do
        expect(@chef_run).to create_file_with_content @file.name,
          "rabbit_hosts=1.1.1.1:5672,2.2.2.2:5672"
      end

      it "has rabbit_ha_queues" do
        expect(@chef_run).to create_file_with_content @file.name,
          "rabbit_ha_queues=True"
      end

      it "does not have rabbit_host" do
        expect(@chef_run).not_to create_file_with_content @file.name,
          "rabbit_host=127.0.0.1"
      end

      it "does not have rabbit_port" do
        expect(@chef_run).not_to create_file_with_content @file.name,
          "rabbit_port=5672"
      end
    end

    describe "/etc/default/neutron-server" do
      before do
        @file = @chef_run.template(
          "/etc/default/neutron-server")
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "root", "root"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "has a correct plugin config path" do
        expect(@chef_run).to create_file_with_content(
          @file.name, "/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini")
      end
    end

    it "does not install sysconfig template" do
      chef_run = ::ChefSpec::ChefRunner.new(
        ::UBUNTU_OPTS.merge(:evaluate_guards => true)) do |n|
          n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
        end
      chef_run.stub_command(/python/, true)
      chef_run.converge "openstack-network::server"
      expect(chef_run).not_to create_file "/etc/sysconfig/neutron"
    end
  end
end
