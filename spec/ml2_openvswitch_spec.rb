# upgrade platform options
# upgrade platform options
# int bridge cmmd
# include recipe plugin_config
# service restart
# service restart
# execute cmd
# execute cmd
# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::ml2_openvswitch' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:kmod_command) { '/usr/share/openvswitch/scripts/ovs-ctl force-reload-kmod' }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['endpoints']['network-openvswitch']['bind_interface'] = 'eth0'
      node.set['openstack']['network']['openvswitch']['integration_bridge'] = 'br-int'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2'
      node.automatic_attrs['kernel']['release'] = '1.2.3'
      runner.converge(described_recipe)
    end
    describe 'recipe' do
      include_context 'neutron-stubs'
      before do
        stub_command(/ip link show/)
        stub_command('ovs-vsctl add-br br-eth1 -- add-port br-eth1 eth1')
        stub_command('ovs-vsctl add-br br-int')
        stub_command('ovs-vsctl add-br br-tun')
        node.set['openstack']['network']['plugins']['ml2']['path'] = '/etc/neutron/plugins/ml2'
        node.set['openstack']['network']['plugins']['ml2']['filename'] = 'openvswitch_agent.ini'
      end
      it 'upgrades openvswitch switch' do
        expect(chef_run).to upgrade_package 'openvswitch-switch'
      end

      it 'upgrades openvswitch datapath dkms' do
        expect(chef_run).to upgrade_package 'openvswitch-datapath-dkms'
      end

      it 'upgrades linux bridge utils' do
        expect(chef_run).to upgrade_package 'bridge-utils'
      end

      it 'sets the openvswitch service to start on boot' do
        expect(chef_run).to enable_service 'openvswitch-switch'
      end

      it 'start the openvswitch service' do
        expect(chef_run).to start_service 'openvswitch-switch'
      end

      it 'upgrades openvswitch agent' do
        expect(chef_run).to upgrade_package 'neutron-plugin-openvswitch-agent'
      end

      it 'sets the openvswitch service to start on boot' do
        expect(chef_run).to enable_service 'neutron-plugin-openvswitch-agent'
      end

      it_behaves_like 'plugin_config builder', 'ml2'

      it 'allows overriding the service names' do
        node.set['openstack']['network']['platform']['neutron_openvswitch_service'] = 'my-ovs-server'
        node.set['openstack']['network']['platform']['neutron_openvswitch_agent_service'] = 'my-ovs-agent'

        %w(my-ovs-server my-ovs-agent).each do |service|
          expect(chef_run).to enable_service service
        end
      end

      it 'allows overriding package options' do
        node.set['openstack']['network']['platform']['package_overrides'] = '--my-override1 --my-override2'

        %w(openvswitch-switch openvswitch-datapath-dkms neutron-plugin-openvswitch neutron-plugin-openvswitch-agent).each do |pkg|
          expect(chef_run).to upgrade_package(pkg).with(options: '--my-override1 --my-override2')
        end
      end

      it 'allows overriding package names' do
        node.set['openstack']['network']['platform']['neutron_openvswitch_packages'] = ['my-openvswitch', 'my-other-openvswitch']
        node.set['openstack']['network']['platform']['neutron_openvswitch_agent_packages'] = ['my-openvswitch-agent', 'my-other-openvswitch-agent']

        %w(my-openvswitch my-other-openvswitch my-openvswitch-agent my-other-openvswitch-agent).each do |pkg|
          expect(chef_run).to upgrade_package(pkg)
        end
      end

      it 'does not create execute resource when openvswitch-datasource-dkms package is not being installed' do
        node.set['openstack']['network']['platform']['neutron_openvswitch_packages'] = ['my-openvswitch', 'my-other-openvswitch']
        chef_run.converge 'openstack-network::ml2_openvswitch'

        resource = chef_run.find_resource('execute', kmod_command)
        expect(resource).to eq(nil)
      end
    end

    describe 'create ovs data network bridge' do
      let(:cmd) { 'ovs-vsctl add-br br-eth1 -- add-port br-eth1 eth1' }
      let(:name) { 'create data network bridge' }
      before do
        stub_command('ovs-vsctl add-br br-int')
        stub_command('ovs-vsctl add-br br-tun')
      end
      include_context 'neutron-stubs'
      context 'bridge mapping interface unset' do
        before do
          node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = nil
        end
      end
      context 'bridge mapping interface set' do
        before do
          node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = 'br-eth1:eth1'
        end
        context 'ext_bridge exists' do
          before do
            stub_command(/ovs-vsctl br-exists br-eth1/).and_return(true)
          end
          it 'does not add data network bridge' do
            expect(chef_run).not_to run_execute(name)
          end
        end
        context 'ext_bridge doesnt exist' do
          before do
            stub_command(/ovs-vsctl br-exists br-eth1/).and_return(false)
          end
          context 'ext_bridge_iface exists' do
            before do
              stub_command(/ip link show eth1/).and_return(true)
            end
            it 'adds data network bridge' do
              expect(chef_run).to run_execute(name)
            end
          end
          context 'ext_bridge_iface doesnt exists' do
            before do
              stub_command(/ip link show eth1/).and_return(false)
            end
            it 'does not add data network bridge' do
              expect(chef_run).not_to run_execute(name)
            end
          end
        end
      end
      describe 'create ovs internal network bridge' do
        let(:cmd) { 'ovs-vsctl add-br br-int' }
        let(:name) { 'create internal network bridge' }
        context 'int_bridge exists' do
          before do
            stub_command('ovs-vsctl br-exists br-int').and_return(false)
          end
          it 'add internal network bridge' do
            expect(chef_run).to run_execute(name)
          end
        end
        context 'int_bridge doesnt exists' do
          before do
            stub_command('ovs-vsctl br-exists br-int').and_return(true)
          end
          it 'does not add internal network bridge' do
            expect(chef_run).not_to run_execute(name)
          end
        end
      end
      describe 'create ovs tunnel network bridge' do
        let(:cmd) { 'ovs-vsctl add-br br-tun' }
        let(:name) { 'create tunnel network bridge' }
        context 'tun_bridge exists' do
          before do
            stub_command('ovs-vsctl br-exists br-tun').and_return(false)
          end
          it 'add tunnel network bridge' do
            expect(chef_run).to run_execute(name)
          end
        end
        context 'tun_bridge doesnt exists' do
          before do
            stub_command('ovs-vsctl br-exists br-tun').and_return(true)
          end
          it 'does not add tunnel network bridge' do
            expect(chef_run).not_to run_execute(name)
          end
        end
      end
    end
  end
end
