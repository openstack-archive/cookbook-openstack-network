# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::dhcp_agent' do
  describe 'centos' do
    let(:runner) { ChefSpec::SoloRunner.new(CENTOS_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    let(:file_cache_path) { Chef::Config[:file_cache_path] }

    include_context 'neutron-stubs'

    it 'does not install openstack-neutron-dhcp-agent when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('neutron-dhcp-agent')
    end

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

    it 'should have the correct dnsmasq remote file' do
      expect(chef_run).to create_remote_file("#{Chef::Config[:file_cache_path]}/2.65-1.el6.rfx.x86_64").with(source: 'http://pkgs.repoforge.org/dnsmasq/dnsmasq-2.65-1.el6.rfx.x86_64.rpm')
    end

    it 'should install the corrcet dnsmasq rpm' do
      expect(chef_run).to install_rpm_package('dnsmasq').with(source: "#{Chef::Config[:file_cache_path]}/2.65-1.el6.rfx.x86_64")
    end

    it 'should notify dhcp agent to restart immediately' do
      expect(chef_run.rpm_package('dnsmasq')).to notify('service[neutron-dhcp-agent]').to(:restart).immediately
    end

    it 'should not have the correct dnsmasq remote file when no version' do
      node.set['openstack']['network']['dhcp']['dnsmasq_rpm_version'] = ''
      expect(chef_run).not_to create_remote_file("#{Chef::Config[:file_cache_path]}/2.65-1.el6.rfx.x86_64")
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
    end
  end
end
