# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install linuxbridge agent package when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not install_package('neutron-plugin-linuxbridge-agent')
    end

    it 'installs linuxbridge agent' do
      expect(chef_run).to install_package('neutron-plugin-linuxbridge-agent')
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

      it 'sets xvlan attributes' do
        expect(chef_run).to render_file(file.name).with_content(
          'enable_vxlan = false')
        expect(chef_run).to render_file(file.name).with_content(
          'ttl = ')
        expect(chef_run).to render_file(file.name).with_content(
          'tos = ')
        expect(chef_run).to render_file(file.name).with_content(
          'vxlan_group = 224.0.0.1')
        expect(chef_run).to render_file(file.name).with_content(
          'l2_population = false')
        expect(chef_run).to render_file(file.name).with_content(
          'polling_interval = 2')
        expect(chef_run).to render_file(file.name).with_content(
          'rpc_support_old_agents = false')
      end

      it 'sets securitygroup attributes' do
        expect(chef_run).to render_file(file.name).with_content(
          'firewall_driver = neutron.agent.firewall.NoopFirewallDriver')
      end

      it 'it uses local_ip from eth0 when local_ip_interface is set' do
        node.set['openstack']['endpoints']['network-linuxbridge']['bind_interface'] = 'eth0'

        expect(chef_run).to render_file(file.name).with_content('local_ip = 10.0.0.2')
      end
    end
  end
end
