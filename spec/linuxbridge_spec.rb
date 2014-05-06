# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.linuxbridge.lb_neutron_plugin.LinuxBridgePluginV2'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install linuxbridge agent package when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('neutron-plugin-linuxbridge-agent')
    end

    it 'upgrades linuxbridge agent' do
      expect(chef_run).to upgrade_package('neutron-plugin-linuxbridge-agent')
    end

    it 'creates the /etc/neutron/plugins/linuxbridge agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/linuxbridge').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0700
      )
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(chef_run).to enable_service('neutron-plugin-linuxbridge-agent')
    end

    it 'subscribes the linuxbridge agent service to neutron.conf' do
      expect(chef_run.service('neutron-plugin-linuxbridge-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    describe '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini') }

      it 'creates linuxbridge_conf.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it 'sets local_ip when bind_interface is not set' do
        expect(chef_run).to render_file(file.name).with_content(
          'local_ip = 127.0.0.1')
      end

      [
        /^tenant_network_type = local$/,
        /^network_vlan_ranges = $/,
        /^physical_interface_mappings = $/,
        /^enable_vxlan = false$/,
        /^ttl = $/,
        /^tos = $/,
        /^vxlan_group = 224.0.0.1$/,
        /^local_ip = 127.0.0.1$/,
        /^l2_population = false$/,
        /^polling_interval = 2$/,
        /^rpc_support_old_agents = false$/,
        /^firewall_driver = neutron.agent.firewall.NoopFirewallDriver$/,
        /^enable_security_group = True$/
      ].each do |content|
        it "has #{content.source[1...-1]} line" do
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end
    end
  end
end
