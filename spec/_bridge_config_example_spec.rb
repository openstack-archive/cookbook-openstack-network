require_relative 'spec_helper'

describe 'openstack-network::_bridge_config_example' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    before do
      %w(eth-ext eth-vlan eth-tun).each do |eth|
        stub_command("ip link show | grep #{eth}")
      end
      allow_any_instance_of(Chef::Recipe).to receive(:address_for)
        .with('eth-tun')
        .and_return('1.2.3.4')
    end

    describe 'create ovs external network bridge and port' do
      let(:cmd_br) { 'ovs-vsctl --may-exist add-br br-ex' }
      let(:cmd_port) { 'ovs-vsctl --may-exist add-port br-ex eth-ext' }
      let(:name) { 'create external network bridge' }

      it 'adds external network bridge' do
        expect(chef_run).to run_execute(name).with(command: cmd_br)
      end
      it 'adds external network bridge port' do
        expect(chef_run).to run_execute("#{name} port").with(command: cmd_port)
      end
    end

    describe 'create vlan network bridge and port' do
      let(:cmd_br) { 'ovs-vsctl --may-exist add-br br-vlan' }
      let(:cmd_port) { 'ovs-vsctl --may-exist add-port br-vlan eth-vlan' }
      let(:name) { 'create vlan network bridge' }

      it 'adds vlan network bridge' do
        expect(chef_run).to run_execute(name).with(command: cmd_br)
      end
      it 'adds vlan network bridge port' do
        expect(chef_run).to run_execute("#{name} port").with(command: cmd_port)
      end
    end

    describe 'create tunnel network bridge' do
      let(:cmd_br) { 'ovs-vsctl --may-exist add-br br-tun' }
      let(:name) { 'create tunnel network bridge' }

      it 'adds tunnel network bridge' do
        expect(chef_run).to run_execute(name).with(command: cmd_br)
      end
    end
  end
end
