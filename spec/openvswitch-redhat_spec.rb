# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'creates the /etc/neutron/plugins/openvswitch agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/openvswitch').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0700
      )
    end

    describe 'ovs_neutron_plugin.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini') }

      it 'create plugin.ini symlink' do
        expect(chef_run).to create_link('/etc/neutron/plugin.ini').with(
          to: file.name,
          owner: 'neutron',
          group: 'neutron'
        )
      end
    end
  end
end
