# pkg upgrade

# service

# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::ml2_linuxbridge' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      node.override['openstack']['network']['plugins']['linuxbridge']['path'] = '/etc/neutron/plugins/linuxbridge'
      node.override['openstack']['network']['plugins']['linuxbridge']['filename'] = 'linuxbridge_conf.ini'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to create_directory('/etc/neutron/plugins/linuxbridge').with(
        owner: 'neutron',
        group: 'neutron',
        mode: '700'
      )
    end

    it do
      expect(chef_run).to include_recipe('openstack-network::plugin_config')
    end

    describe '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini' do
      let(:file) do
        chef_run.template('/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini')
      end

      [
        /^firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver$/,
      ].each do |line|
        it "[securitygroup] #{line}" do
          expect(chef_run).to render_config_file(file.name).with_section_content('securitygroup', line)
        end
      end
    end

    it do
      expect(chef_run).to upgrade_package 'neutron-linuxbridge-agent'
    end

    it do
      expect(chef_run).to enable_service('neutron-plugin-linuxbridge-agent').with(
        service_name: 'neutron-linuxbridge-agent',
        supports: {
          status: true,
          restart: true,
        }
      )
    end

    it do
      expect(chef_run).to start_service('neutron-plugin-linuxbridge-agent')
    end

    %w(
      template[/etc/neutron/neutron.conf]
      template[/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini]
    ).each do |resource|
      it do
        expect(chef_run.service('neutron-plugin-linuxbridge-agent')).to subscribe_to(resource).delayed
      end
    end
  end
end
