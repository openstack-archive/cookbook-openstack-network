# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end
    include_context 'neutron-stubs'

    it do
      expect(chef_run).to include_recipe('openstack-network')
    end

    it 'subscribes the agent service to neutron.conf' do
      expect(chef_run.service('neutron-dhcp-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    it 'upgrades neutron dhcp package' do
      expect(chef_run).to upgrade_package 'neutron-dhcp-agent'
    end

    it 'starts the dhcp agent on boot' do
      expect(chef_run).to enable_service 'neutron-dhcp-agent'
    end
    describe 'dhcp_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/dhcp_agent.ini') }

      it 'creates dhcp_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0o644
        )
      end
    end
    describe '/etc/neutron/dnsmasq.conf' do
      let(:file) { chef_run.template('/etc/neutron/dnsmasq.conf') }

      it 'creates dnsmasq.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0o644
        )
      end
    end
  end
end
