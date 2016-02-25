# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['network']['openvswitch']['integration_bridge'] = 'br-int'
      runner.converge(described_recipe)
    end
    before do
      stub_command('ovs-vsctl --may-exist add-br br-int')
    end

    it 'upgrades openvswitch agent' do
      expect(chef_run).to upgrade_package 'neutron-plugin-openvswitch-agent'
    end

    describe 'create integration network bridget' do
      let(:cmd_br) { 'ovs-vsctl --may-exist add-br br-int' }
      let(:name) { 'create integration network bridge' }
      it 'adds integration network bridge' do
        expect(chef_run).to run_execute(name)
          .with(command: cmd_br)
      end
    end

    it 'sets the openvswitch_agent service to start on boot' do
      expect(chef_run).to enable_service 'neutron-plugin-openvswitch-agent'
    end

    it 'starts the openvswitch_agent service' do
      expect(chef_run).to start_service 'neutron-plugin-openvswitch-agent'
    end
  end
end
