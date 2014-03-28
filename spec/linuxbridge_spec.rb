# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do

  describe 'ubuntu' do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
        n.set['openstack']['db']['network']['db_name'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::linuxbridge'
    end

    it 'does not install linuxbridge agent package when nova networking' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      chef_run.converge 'openstack-network::linuxbridge'
      expect(chef_run).to_not install_package 'neutron-plugin-linuxbridge-agent'
    end

    it 'installs linuxbridge agent' do
      expect(@chef_run).to install_package 'neutron-plugin-linuxbridge-agent'
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(@chef_run).to enable_service 'neutron-plugin-linuxbridge-agent'
    end

    describe '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini' do
      before do
        @file = @chef_run.template(
          '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini')
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'sets local_ip when bind_interface is not set' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'local_ip = 127.0.0.1')
      end

      it 'sets xvlan attributes' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'enable_vxlan = false')
        expect(@chef_run).to render_file(@file.name).with_content(
          'ttl = ')
        expect(@chef_run).to render_file(@file.name).with_content(
          'tos = ')
        expect(@chef_run).to render_file(@file.name).with_content(
          'vxlan_group = 224.0.0.1')
        expect(@chef_run).to render_file(@file.name).with_content(
          'l2_population = false')
        expect(@chef_run).to render_file(@file.name).with_content(
          'polling_interval = 2')
        expect(@chef_run).to render_file(@file.name).with_content(
          'rpc_support_old_agents = false')
      end

      it 'sets securitygroup attributes' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'firewall_driver = neutron.agent.firewall.NoopFirewallDriver')
      end

      it 'it uses local_ip from eth0 when bind_interface is set' do
        chef_run = ::ChefSpec::Runner.new(::UBUNTU_OPTS) do |n|
          n.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'
          n.set['openstack']['compute']['network']['service_type'] = 'neutron'
          n.set['openstack']['endpoints']['network-linuxbridge']['bind_interface'] = 'eth0'
        end
        filename = '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini'
        chef_run.converge 'openstack-network::linuxbridge'
        expect(chef_run).to render_file(filename).with_content('local_ip = 10.0.0.2')
      end
    end
  end
end
