# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not include recipe openstack-network::comon when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not include_recipe('openstack-network::common')
    end

    it 'subscribes the agent service to neutron.conf' do
      expect(chef_run.service('neutron-dhcp-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    # since our mocked version of ubuntu is precise, our compile
    # utilities should be installed to build dnsmasq
    it 'upgrades dnsmasq build dependencies' do
      %w(build-essential pkg-config libidn11-dev libdbus-1-dev libnetfilter-conntrack-dev gettext).each do |pkg|
        expect(chef_run).to upgrade_package pkg
      end
    end

    it 'skips dnsmasq build when asked to' do
      node.set['openstack']['network']['dhcp']['dnsmasq_compile'] = false

      %w(build-essential pkg-config libidn11-dev libdbus-1-dev libnetfilter-conntrack-dev gettext).each do |pkg|
        expect(chef_run).to_not upgrade_package pkg
      end
    end

    it 'upgrades neutron dhcp package' do
      expect(chef_run).to upgrade_package 'neutron-dhcp-agent'
    end

    it 'upgrades plugin package' do
      expect(chef_run).to upgrade_package 'neutron-plugin-ml2'
    end

    it 'starts the dhcp agent on boot' do
      expect(chef_run).to enable_service 'neutron-dhcp-agent'
    end

    describe '/etc/neutron/plugins' do
      let(:dir) { chef_run.directory('/etc/neutron/plugins') }

      it 'creates /etc/neutron/plugins' do
        expect(chef_run).to create_directory(dir.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0700
        )
      end
    end

    describe '/etc/neutron/dhcp_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/dhcp_agent.ini') }

      it 'creates dhcp_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it 'uses ovs driver' do
        expect(chef_run).to render_file(file.name).with_content(
          'interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver')
      end

      it 'uses namespaces' do
        expect(chef_run).to render_file(file.name).with_content('use_namespaces = True')
      end

      it 'disables ovs_use_veth' do
        expect(chef_run).to render_file(file.name).with_content('ovs_use_veth = False')
      end

      it 'checks dhcp domain' do
        expect(chef_run).to render_file(file.name).with_content(/^dhcp_domain = openstacklocal$/)
      end

      it 'has default dnsmasq_lease_max setting' do
        expect(chef_run).to render_file(file.name).with_content(/^dnsmasq_lease_max = 16777216$/)
      end

      it 'has configurable dnsmasq_lease_max setting' do
        node.set['openstack']['network']['dhcp']['dnsmasq_lease_max'] = 16777215

        expect(chef_run).to render_file(file.name).with_content(/^dnsmasq_lease_max = 16777215$/)
      end

      it 'notifies the dhcp agent service' do
        expect(file).to notify('service[neutron-dhcp-agent]').to(:restart).immediately
      end
    end

    describe '/etc/neutron/dnsmasq.conf' do
      let(:file) { chef_run.template('/etc/neutron/dnsmasq.conf') }

      it 'creates dnsmasq.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it 'overrides dhcp options' do
        expect(chef_run).to render_file(file.name).with_content('dhcp-option=26,1454')
      end

      it 'checks upstream resolvers' do
        expect(chef_run).to render_file(file.name).with_content(/^server=209.244.0.3$/)
        expect(chef_run).to render_file(file.name).with_content(/^server=8.8.8.8$/)
      end

      it 'notifies the dhcp agent service' do
        expect(file).to notify('service[neutron-dhcp-agent]').to(:restart).delayed
      end
    end
  end
end
