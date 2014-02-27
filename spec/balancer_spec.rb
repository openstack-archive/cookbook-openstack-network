# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::balancer' do

  describe 'ubuntu' do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::balancer'
    end

    it 'does not install neutron-lbaas-agent when nova networking.' do
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      @chef_run.converge 'openstack-network::balancer'
      expect(@chef_run).to_not install_package 'neutron-lbaas-agent'
    end

    ['haproxy', 'neutron-lbaas-agent'].each do |pack|
      it "installs #{pack} package" do
        expect(@chef_run).to install_package pack
      end
    end

    describe 'lbaas_agent.ini' do
      before do
        @file = @chef_run.template '/etc/neutron/lbaas_agent.ini'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end

      it 'has proper mode' do
        expect(sprintf('%o', @file.mode)).to eq '640'
      end

      it 'has default settings' do
        expect(@chef_run).to render_file(@file.name).with_content(/periodic_interval = 10/)
        expect(@chef_run).to render_file(@file.name).with_content(
          /interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/)
      end

    end

  end

end
