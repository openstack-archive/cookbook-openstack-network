# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'suse' do
    let(:runner) { ChefSpec::Runner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install openstack-neutron when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package 'openstack-neutron'
    end

    it 'upgrades openstack-neutron packages' do
      expect(chef_run).to upgrade_package 'openstack-neutron'
    end

    it 'enables openstack-neutron service' do
      expect(chef_run).to enable_service 'openstack-neutron'
    end

    it 'does not upgrade openvswitch package' do
      expect(chef_run).not_to upgrade_package 'openstack-neutron-openvswitch'
    end

    describe '/etc/sysconfig/neutron' do
      let(:file) { chef_run.template('/etc/sysconfig/neutron') }

      it 'creates /etc/sysconfig/neutron' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0644
        )
      end

      it 'has the correct plugin config location - ml2 by default' do
        expect(chef_run).to render_file(file.name).with_content(
          '/etc/neutron/plugins/ml2/ml2_conf.ini')
      end

      it 'uses linuxbridge when configured to use it' do
        chef_run = ::ChefSpec::Runner.new ::SUSE_OPTS do |n|
          n.set['openstack']['network']['core_plugin'] = 'neutron.plugins.linuxbridge.lb_neutron_plugin.LinuxBridgePluginV2'
          n.set['openstack']['compute']['network']['service_type'] = 'neutron'
        end
        chef_run.converge 'openstack-network::server'

        expect(chef_run).to render_file(file.name).with_content(
          '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini')
      end
    end
  end
end
