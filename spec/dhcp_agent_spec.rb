# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not include recipe openstack-network::comon when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not include_recipe('openstack-network')
    end

    it 'subscribes the agent service to neutron.conf' do
      expect(chef_run.service('neutron-dhcp-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
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

      it_behaves_like 'dhcp agent template configurator' do
        let(:file_name) { file.name }
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

      it_behaves_like 'dnsmasq template configurator' do
        let(:file_name) { file.name }
      end

      it 'notifies the dhcp agent service' do
        expect(file).to notify('service[neutron-dhcp-agent]').to(:restart).delayed
      end
    end
  end
end
