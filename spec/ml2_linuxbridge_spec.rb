# pkg upgrade

# service

# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::ml2_linuxbridge' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    before do
      node.set['openstack']['network']['plugins']['linuxbridge']['path'] =
        '/etc/neutron/plugins/linuxbridge'
      node.set['openstack']['network']['plugins']['linuxbridge']['filename'] =
        'linuxbridge_conf.ini'
    end
    it 'creates the /etc/neutron/plugins/linuxbridge agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/linuxbridge').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0o700
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
        /^firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver$/
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('securitygroup', line)
        end
      end
    end

    it do
      %w(neutron-plugin-linuxbridge neutron-plugin-linuxbridge-agent).each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end

    it do
      expect(chef_run).to enable_service('neutron-plugin-linuxbridge-agent')
    end
    it do
      service = chef_run.service('neutron-plugin-linuxbridge-agent')
      expect(service).to(subscribe_to('template[/etc/neutron/neutron.conf]').on(:restart).delayed) && subscribe_to('template[/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini]').on(:restart).delayed
    end
  end
end
