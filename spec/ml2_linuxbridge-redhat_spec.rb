# pkg upgrade

# service

# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::ml2_linuxbridge' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['network']['plugins']['linuxbridge']['path'] = '/etc/neutron/plugins/ml2'
      node.override['openstack']['network']['plugins']['linuxbridge']['filename'] = 'linuxbridge_agent.ini'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'creates the /etc/neutron/plugins/ml2 agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/ml2').with(
        owner: 'neutron',
        group: 'neutron',
        mode: '700'
      )
    end
    it do
      expect(chef_run).to include_recipe('openstack-network::plugin_config')
    end

    describe '/etc/neutron/plugins/ml2/linuxbridge_agent.ini' do
      let(:file) do
        chef_run.template('/etc/neutron/plugins/ml2/linuxbridge_agent.ini')
      end
      [
        /^firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('securitygroup', line)
        end
      end
    end

    it do
      expect(chef_run).to upgrade_package(%w(openstack-neutron-linuxbridge iproute))
    end

    it do
      expect(chef_run).to enable_service('neutron-linuxbridge-agent')
    end
    it do
      service = chef_run.service('neutron-linuxbridge-agent')
      expect(service).to(subscribe_to('template[/etc/neutron/neutron.conf]').on(:restart).delayed) && subscribe_to('template[/etc/neutron/plugins/ml2/linuxbridge_agent.ini]').on(:restart).delayed
    end
  end
end
