# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  describe 'redhat' do
    let(:runner) { ChefSpec::Runner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2'

      runner.converge(described_recipe)
    end
    let(:file) { chef_run.template('/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini') }

    include_context 'neutron-stubs'

    it 'notifies to create symbolic link' do
      expect(file).to notify('link[/etc/neutron/plugin.ini]').to(:create).immediately
    end

    it 'creates the /etc/neutron/plugins/openvswitch agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/openvswitch').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0700
      )
    end

    it 'creates ovs_neutron_plugin.ini' do
      expect(chef_run).to create_template(file.name).with(
        user: 'neutron',
        group: 'neutron',
        mode: 0644
      )
    end
  end
end
