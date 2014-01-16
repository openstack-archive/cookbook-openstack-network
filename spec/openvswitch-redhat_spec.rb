# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do

  describe 'redhat' do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::openvswitch'
      @file = @chef_run.template('/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini')
    end

    it 'notifies to create symbolic link' do
      expect(@file).to notify('link[/etc/neutron/plugin.ini]').to(:create).immediately
    end

  end
end
