# pkg upgrade

# service

# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::ml2_openvswitch' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe, 'openstack-network::plugin_config')
    end

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to include_recipe('openstack-network::ml2_core_plugin')
    end

    describe '/etc/neutron/plugins/ml2/openvswitch_agent.ini' do
      let(:file) do
        chef_run.template('/etc/neutron/plugins/ml2/openvswitch_agent.ini')
      end

      [
        /^integration_bridge = br-int$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', line)
        end
      end
    end
  end
end
