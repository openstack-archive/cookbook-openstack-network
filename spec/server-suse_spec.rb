# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
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

      PLUGIN_MAP.each do |plugin_name, plugin_cfg|
        it "sets the path to the #{plugin_name} plugin config" do
          node.set['openstack']['network']['core_plugin'] = plugin_name
          node.set['openstack']['network']['plugin_conf_map'][plugin_name] = plugin_cfg
          node.set['openstack']['network']['core_plugin_map'][plugin_name] = plugin_name
          expect(chef_run).to render_file(file.name).with_content(%r{^NEUTRON_PLUGIN_CONF="/etc/neutron/plugins/#{plugin_cfg}"$})
        end
      end
    end
  end
end
