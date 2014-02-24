# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do

  describe 'ubuntu' do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::dhcp_agent'
    end

    it 'does not include recipe openstack-network::comon when nova networking' do
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      @chef_run.converge 'openstack-network::dhcp_agent'
      expect(@chef_run).to_not include_recipe  'openstack-network::common'
    end

    # since our mocked version of ubuntu is precise, our compile
    # utilities should be installed to build dnsmasq
    it 'installs dnsmasq build dependencies' do
      %w(build-essential pkg-config libidn11-dev libdbus-1-dev libnetfilter-conntrack-dev gettext).each do |pkg|
        expect(@chef_run).to install_package pkg
      end
    end

    it 'skips dnsmasq build when asked to' do
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = @chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'quantum'
      node.set['openstack']['network']['dhcp']['dnsmasq_compile'] = false
      @chef_run.converge 'openstack-network::dhcp_agent'
      %w(build-essential pkg-config libidn11-dev libdbus-1-dev libnetfilter-conntrack-dev gettext).each do |pkg|
        expect(@chef_run).to_not install_package pkg
      end
    end

    it 'installs quamtum dhcp package' do
      expect(@chef_run).to install_package 'neutron-dhcp-agent'
    end

    it 'installs plugin packages' do
      expect(@chef_run).to install_package 'neutron-plugin-openvswitch'
    end

    it 'starts the dhcp agent on boot' do
      expect(@chef_run).to enable_service 'neutron-dhcp-agent'
    end

    describe '/etc/neutron/plugins' do
      before do
        @file = @chef_run.directory '/etc/neutron/plugins'
      end
      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end
      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '700'
      end
    end

    describe '/etc/neutron/dhcp_agent.ini' do
      before do
        @file = @chef_run.template '/etc/neutron/dhcp_agent.ini'
      end
      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end
      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end
      it 'uses ovs driver' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver')
      end
      it 'uses namespaces' do
        expect(@chef_run).to render_file(@file.name).with_content('use_namespaces = True')
      end
      it 'checks dhcp domain' do
        expect(@chef_run).to render_file(@file.name).with_content(/^dhcp_domain = openstacklocal$/)
      end
      it 'has default dnsmasq_lease_max setting' do
        expect(@chef_run).to render_file(@file.name).with_content(/^dnsmasq_lease_max = 16777216$/)
      end
      it 'has configurable dnsmasq_lease_max setting' do
        node = @chef_run.node
        node.set['openstack']['network']['dhcp']['dnsmasq_lease_max'] = 16777215
        @chef_run.converge 'openstack-network::dhcp_agent'
        expect(@chef_run).to render_file(@file.name).with_content(/^dnsmasq_lease_max = 16777215$/)
      end
    end

    describe '/etc/neutron/dnsmasq.conf' do
      before do
        @file = @chef_run.template '/etc/neutron/dnsmasq.conf'
      end
      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end
      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end
      it 'overrides dhcp options' do
        expect(@chef_run).to render_file(@file.name).with_content('dhcp-option=26,1454')
      end
      it 'checks upstream resolvers' do
        expect(@chef_run).to render_file(@file.name).with_content(/^server=209.244.0.3$/)
        expect(@chef_run).to render_file(@file.name).with_content(/^server=8.8.8.8$/)
      end
    end
  end
end
