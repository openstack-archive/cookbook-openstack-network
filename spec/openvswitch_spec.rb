# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
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

    include_context 'neutron-stubs'

    it 'does not install openvswitch switch when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package 'openvswitch-switch'
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

    it 'upgrades linux linux headers' do
      expect(chef_run).to upgrade_package 'linux-headers-1.2.3'
    end

    it 'sets the openvswitch service to start on boot' do
      expect(chef_run).to enable_service 'openvswitch-switch'
    end

    it 'start the openvswitch service' do
      expect(chef_run).to start_service 'openvswitch-switch'
    end

    it 'subscribes the openvswitch agent service to neutron.conf' do
      expect(chef_run.service('neutron-plugin-openvswitch-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    it 'upgrades openvswitch agent' do
      expect(chef_run).to upgrade_package 'neutron-plugin-openvswitch-agent'
    end

    it 'creates the /etc/neutron/plugins/openvswitch agent directory' do
      expect(chef_run).to create_directory('/etc/neutron/plugins/openvswitch').with(
        owner: 'neutron',
        group: 'neutron',
        mode: 0700
      )
    end

    it 'sets the openvswitch service to start on boot' do
      expect(chef_run).to enable_service 'neutron-plugin-openvswitch-agent'
    end

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

    it 'creates execute resource when openvswitch-datasource-dkms package is being installed' do
      resource = chef_run.find_resource('execute', kmod_command).to_hash

      expect(resource).to include(
        action: [:nothing],
        command: kmod_command
      )
    end

    it 'does not create execute resource when openvswitch-datasource-dkms package is not being installed' do
      node.set['openstack']['network']['platform']['neutron_openvswitch_packages'] = ['my-openvswitch', 'my-other-openvswitch']
      chef_run.converge 'openstack-network::openvswitch'

      resource = chef_run.find_resource('execute', kmod_command)
      expect(resource).to eq(nil)
    end

    it 'notifies :run to the force-reload-kmod execute resource when openvswitch-datapath-dkms is installed' do
      expect(chef_run.package('openvswitch-datapath-dkms')).to notify("execute[#{kmod_command}]").to(:run).immediately
    end

    describe 'create ovs data network bridge' do
      let(:cmd) { 'ovs-vsctl add-br br-eth1 -- add-port br-eth1 eth1' }

      it 'does not add data network bridge if it already exists' do
        node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = 'br-eth1:eth1'
        stub_command(/ovs-vsctl br-exists br-eth1/).and_return(true)
        stub_command(/ip link show eth1/).and_return(true)
        expect(chef_run).not_to run_execute(cmd)
      end

      it 'does not add data network bridge if the physical interface does not exist' do
        node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = 'br-eth1:eth1'
        stub_command(/ovs-vsctl br-exists br-eth1/).and_return(false)
        stub_command(/ip link show eth1/).and_return(false)
        expect(chef_run).not_to run_execute(cmd)
      end

      it 'adds data network bridge if it does not yet exist and physical interface exists' do
        node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = 'br-eth1:eth1'
        stub_command(/ovs-vsctl br-exists br-eth1/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)
        expect(chef_run).to run_execute(cmd)
      end

      it 'does not add data network bridge if nil specified for bridge mapping' do
        node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = nil
        stub_command(/ovs-vsctl br-exists br-eth1/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)
        expect(chef_run).not_to run_execute(cmd)
      end

      it 'does not add data network bridge if emtpy string specified for bridge mapping' do
        node.set['openstack']['network']['openvswitch']['bridge_mapping_interface'] = ''
        stub_command(/ovs-vsctl br-exists br-eth1/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)
        expect(chef_run).not_to run_execute(cmd)
      end
    end
  end
end
