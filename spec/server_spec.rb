require_relative 'spec_helper'

describe 'openstack-network::server' do
  before { quantum_stubs }
  before do
    @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
      n.set["openstack"]["mq"] = {
        "host" => "127.0.0.1"
      }
      n.set["chef_client"]["splay"] = 300
      n.set["openstack"]["network"]["quota"]["driver"] = "my.quota.Driver"
    end
    @chef_run.converge "openstack-network::server"
  end

  describe "package and services" do

    it "installs quantum packages" do
      expect(@chef_run).to install_package "quantum-server"
    end

    it "starts server service" do
      expect(@chef_run).to enable_service "quantum-server"
    end

    it "does not install openvswitch package or the agent" do
      expect(@chef_run).not_to install_package "openvswitch"
      expect(@chef_run).not_to install_package "quantum-plugin-openvswitch-agent"
      expect(@chef_run).not_to enable_service "quantum-plugin-openvswitch-agent"
    end

  end

  describe "api-paste.ini" do

    before do
     @file = @chef_run.template "/etc/quantum/api-paste.ini"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "quantum", "quantum"
    end

    it "has proper modes" do
     expect(sprintf("%o", @file.mode)).to eq "640"
    end

    it "has quantum pass" do
      expect(@chef_run).to create_file_with_content @file.name,
        "admin_password = quantum-pass"
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

  it "should create quantum-ha-tool.py script" do
    expect(@chef_run).to create_cookbook_file "/usr/local/bin/quantum-ha-tool.py"
  end

  describe "quantum.conf" do

    before do
     @file = @chef_run.template "/etc/quantum/quantum.conf"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "quantum", "quantum"
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
        'root_helper = "sudo quantum-rootwrap /etc/quantum/rootwrap.conf"'
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
        "admin_password = quantum-pass"
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
        @file = @chef_run.template "/etc/quantum/quantum.conf"
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
        "network_scheduler_driver = quantum.scheduler.dhcp_agent_scheduler.ChanceScheduler"
      expect(@chef_run).to create_file_with_content @file.name,
        "router_scheduler_driver = quantum.scheduler.l3_agent_scheduler.ChanceScheduler"
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

    describe "quantum.conf with rabbit ha" do

      before do
        @chef_run = ::ChefSpec::ChefRunner.new(::UBUNTU_OPTS) do |n|
          n.set["openstack"]["network"]["rabbit"]["ha"] = true
          n.set["chef_client"]["splay"] = 300
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

    describe "/etc/default/quantum-server" do
      before do
        @file = @chef_run.template(
          "/etc/default/quantum-server")
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "root", "root"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "has a correct plugin config path" do
        expect(@chef_run).to create_file_with_content(
          @file.name, "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini")
      end
    end

    it "does not install sysconfig template" do
      chef_run = ::ChefSpec::ChefRunner.new(
        ::UBUNTU_OPTS.merge(:evaluate_guards => true))
      chef_run.stub_command(/python/, true)
      chef_run.converge "openstack-network::server"
      expect(chef_run).not_to create_file "/etc/sysconfig/quantum"
    end
  end
end
