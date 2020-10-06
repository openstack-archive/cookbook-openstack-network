require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end
    include_context 'neutron-stubs'

    it do
      expect(chef_run).to include_recipe('openstack-network')
    end

    %w(
      template[/etc/neutron/neutron.conf]
      template[/etc/neutron/dnsmasq.conf]
      template[/etc/neutron/dhcp_agent.ini]
    ).each do |resource|
      it do
        expect(chef_run.service('neutron-dhcp-agent')).to subscribe_to(resource).delayed
      end
    end

    it do
      expect(chef_run).to_not upgrade_rpm_package('dnsmasq')
    end

    it do
      expect(chef_run).to upgrade_package 'neutron-dhcp-agent'
    end

    it do
      expect(chef_run).to enable_service('neutron-dhcp-agent').with(
        service_name: 'neutron-dhcp-agent',
        supports: {
          restart: true,
          status: true,
        }
      )
    end

    it do
      expect(chef_run).to start_service 'neutron-dhcp-agent'
    end
    describe 'dhcp_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/dhcp_agent.ini') }

      it 'creates dhcp_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          source: 'openstack-service.conf.erb',
          cookbook: 'openstack-common',
          user: 'neutron',
          group: 'neutron',
          mode: '644'
        )
      end
      [
        /^interface_driver = openvswitch$/,
        %r{^dnsmasq_config_file  = /etc/neutron/dnsmasq.conf$},
      ].each do |line|
        it do
          expect(chef_run).to render_config_file('/etc/neutron/dhcp_agent.ini').with_section_content('DEFAULT', line)
        end
      end
    end
    describe '/etc/neutron/dnsmasq.conf' do
      let(:file) { chef_run.template('/etc/neutron/dnsmasq.conf') }

      it 'creates dnsmasq.conf' do
        expect(chef_run).to create_template(file.name).with(
          source: 'dnsmasq.conf.erb',
          user: 'neutron',
          group: 'neutron',
          mode: '644'
        )
      end
      [
        /^server=8.8.8.8$/,
        /^server=208.67.222.222$/,
      ].each do |line|
        it do
          expect(chef_run).to render_file('/etc/neutron/dnsmasq.conf').with_content(line)
        end
      end
    end
  end
end
