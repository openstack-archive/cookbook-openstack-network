# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::balancer' do
  describe 'redhat' do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::SUSE_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::balancer'
    end

    ['haproxy', 'openstack-neutron-lbaas'].each do |pack|
      it "installs #{pack} package" do
        expect(@chef_run).to install_package pack
      end
    end
  end
end
