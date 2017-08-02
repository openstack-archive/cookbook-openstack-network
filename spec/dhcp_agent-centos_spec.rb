# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'centos' do
    let(:runner) { ChefSpec::SoloRunner.new(CENTOS_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    let(:file_cache_path) { Chef::Config[:file_cache_path] }

    include_context 'neutron-stubs'

    it 'upgrades neutron dhcp package' do
      expect(chef_run).to upgrade_package('openstack-neutron')
    end

    it 'upgrades plugin packages' do
      expect(chef_run).not_to upgrade_package(/openvswitch/)
      expect(chef_run).not_to upgrade_package(/plugin/)
    end

    it 'starts the dhcp agent on boot' do
      expect(chef_run).to enable_service('neutron-dhcp-agent')
    end

    it 'should install the dnsmasq rpm' do
      expect(chef_run).to upgrade_rpm_package('dnsmasq')
    end

    it 'should notify dhcp agent to restart immediately' do
      expect(chef_run.rpm_package('dnsmasq')).to notify('service[neutron-dhcp-agent]').to(:restart).delayed
    end

    describe '/etc/neutron/dhcp_agent.ini' do
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
