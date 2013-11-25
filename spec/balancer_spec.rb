require_relative 'spec_helper'

describe 'openstack-network::balancer' do

  describe "ubuntu" do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
      @chef_run.converge "openstack-network::balancer"
    end

    it "does not install neutron-lbaas-agent when nova networking." do
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
      @chef_run.converge "openstack-network::balancer"
      expect(@chef_run).to_not install_package "neutron-lbaas-agent"
    end

    ['haproxy', 'neutron-lbaas-agent'].each do |pack|
      it "installs #{pack} package" do
        expect(@chef_run).to install_package pack
      end
    end

    it 'creates directory /etc/neutron/plugins/services/agent_loadbalancer' do
      expect(@chef_run).to create_directory '/etc/neutron/plugins/services/agent_loadbalancer'
    end

    it 'balancer config' do
      configf = "/etc/neutron/plugins/services/agent_loadbalancer/lbaas_agent.ini"
      expect(@chef_run).to create_file configf
      expect(@chef_run).to create_file_with_content configf, /periodic_interval = 10/
      expect(@chef_run).to create_file_with_content configf, /interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/
    end

  end

end
