# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do

  describe 'redhat' do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS do |n|
        n.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::linuxbridge'
      @file = @chef_run.template('/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini')
    end

    it 'does not install linuxbridge agent package when nova networking' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      chef_run.converge 'openstack-network::linuxbridge'
      expect(chef_run).to_not install_package 'openstack-neutron-linuxbridge'
    end

    it 'installs linuxbridge agent' do
      expect(@chef_run).to install_package 'openstack-neutron-linuxbridge'
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(@chef_run).to enable_service 'neutron-linuxbridge-agent'
    end

    it 'notifies to create symbolic link' do
      expect(@file).to notify('link[/etc/neutron/plugin.ini]').to(:create).immediately
    end

  end
end
