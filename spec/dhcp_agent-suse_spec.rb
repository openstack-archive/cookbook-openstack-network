# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install openstack-neutron-dhcp-agent when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('openstack-neutron-dhcp-agent')
    end

    it 'upgrades neutron dhcp package' do
      expect(chef_run).to upgrade_package('openstack-neutron-dhcp-agent')
    end

    it 'upgrades plugin packages' do
      expect(chef_run).not_to upgrade_package(/openvswitch/)
      expect(chef_run).not_to upgrade_package(/plugin/)
    end

    it 'starts the dhcp agent on boot' do
      expect(chef_run).to enable_service('openstack-neutron-dhcp-agent')
    end

    describe '/etc/neutron/dhcp_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/dhcp_agent.ini') }

      it 'creates dhcp_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'openstack-neutron',
          group: 'openstack-neutron',
          mode: 0644
        )
      end

      it_behaves_like 'dhcp agent template configurator' do
        let(:file_name) { file.name }
      end
    end

    describe '/etc/neutron/dnsmasq.conf' do
      let(:file) { chef_run.template('/etc/neutron/dnsmasq.conf') }

      it 'creates dnsmasq.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'openstack-neutron',
          group: 'openstack-neutron',
          mode: 0644
        )
      end

      it_behaves_like 'dnsmasq template configurator' do
        let(:file_name) { file.name }
      end
    end
  end
end
