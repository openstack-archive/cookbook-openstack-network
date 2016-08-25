# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::vpnaas' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'
    it 'include the recipe openstack-network::default' do
      expect(chef_run).to include_recipe('openstack-network::default')
    end

    it 'upgrades vpn device driver packages' do
      expect(chef_run).to upgrade_package('strongswan')
    end

    it 'upgrades neutron vpn packages' do
      expect(chef_run).to upgrade_package('neutron-vpn-agent')
      expect(chef_run).to upgrade_package('python-neutron-vpnaas')
    end

    it 'starts strongswan on boot' do
      expect(chef_run).to enable_service('strongswan')
    end

    it 'starts the vpn agent on boot' do
      expect(chef_run).to enable_service('neutron-vpn-agent')
    end

    it 'subscribes the vpn agent service to neutron.conf' do
      expect(chef_run.service('neutron-vpn-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    describe 'vpn_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/vpn_agent.ini') }

      it 'creates vpn_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end

      describe 'vpn_device_driver' do
        it 'renders one vpn_device_driver entry in vpn_agent.ini for default vpn_device_driver' do
          [/^vpn_device_driver = neutron_vpnaas.services.vpn.device_drivers.strongswan_ipsec.StrongSwanDriver$/].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('vpnagent', line)
          end
        end

        it 'renders no setted vpn_device_driver entry in vpn_agent.ini, when no vpn_device_driver set' do
          chef_run.node.set['openstack']['network_vpnaas']['conf']['vpnagent']['vpn_device_driver'] = ''
          chef_run.converge(described_recipe)
          expect(chef_run).to render_config_file(file.name).with_section_content('vpnagent', /^vpn_device_driver = $/)
        end
      end

      it 'renders default_config_area for strongswan driver' do
        expect(chef_run).to render_config_file(file.name).with_section_content('strongswan', %r{^default_config_area = /etc/strongswan.d$})
      end

      it 'notifies the vpn agent service' do
        expect(file).to notify('service[neutron-vpn-agent]').to(:restart).delayed
      end
    end
  end
end
