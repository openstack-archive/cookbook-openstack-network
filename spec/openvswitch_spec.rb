# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  before do
    neutron_stubs
    @kmod_command = '/usr/share/openvswitch/scripts/ovs-ctl force-reload-kmod'
    @chef_run = ::ChefSpec::Runner.new(::UBUNTU_OPTS) do |n|
      n.automatic_attrs['kernel']['release'] = '1.2.3'
      n.set['openstack']['network']['local_ip_interface'] = 'eth0'
      n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      n.set['openstack']['network']['openvswitch']['integration_bridge'] = 'br-int'
    end
    @chef_run.converge 'openstack-network::openvswitch'
  end

  it 'does not install openvswitch switch when nova networking' do
    chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set['openstack']['compute']['network']['service_type'] = 'nova'
    chef_run.converge 'openstack-network::openvswitch'
    expect(chef_run).to_not install_package 'openvswitch-switch'
  end

  it 'installs openvswitch switch' do
    expect(@chef_run).to install_package 'openvswitch-switch'
  end

  it 'installs openvswitch datapath dkms' do
    expect(@chef_run).to install_package 'openvswitch-datapath-dkms'
  end

  it 'installs linux bridge utils' do
    expect(@chef_run).to install_package 'bridge-utils'
  end

  it 'installs linux linux headers' do
    expect(@chef_run).to install_package 'linux-headers-1.2.3'
  end

  it 'sets the openvswitch service to start on boot' do
    expect(@chef_run).to enable_service 'openvswitch-switch'
  end

  it 'restarts the openvswitch service' do
    expect(@chef_run).to restart_service 'openvswitch-switch'
  end

  it 'installs openvswitch agent' do
    expect(@chef_run).to install_package 'neutron-plugin-openvswitch-agent'
  end

  it 'sets the openvswitch service to start on boot' do
    expect(@chef_run).to enable_service 'neutron-plugin-openvswitch-agent'
  end

  it 'allows overriding the service names' do
    chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set['openstack']['compute']['network']['service_type'] = 'neutron'
    node.set['openstack']['network']['platform']['neutron_openvswitch_service'] = 'my-ovs-server'
    node.set['openstack']['network']['platform']['neutron_openvswitch_agent_service'] = 'my-ovs-agent'
    chef_run.converge 'openstack-network::openvswitch'

    %w{my-ovs-server my-ovs-agent}.each do |service|
      expect(chef_run).to enable_service service
    end
  end

  it 'allows overriding package options' do
    chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set['openstack']['compute']['network']['service_type'] = 'neutron'
    node.set['openstack']['network']['platform']['package_overrides'] = '--my-override1 --my-override2'
    chef_run.converge 'openstack-network::openvswitch'

    %w{openvswitch-switch openvswitch-datapath-dkms neutron-plugin-openvswitch neutron-plugin-openvswitch-agent}.each do |pkg|
      expect(chef_run).to install_package(pkg).with(options: '--my-override1 --my-override2')
    end
  end

  it 'allows overriding package names' do
    chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set['openstack']['compute']['network']['service_type'] = 'neutron'
    node.set['openstack']['network']['platform']['neutron_openvswitch_packages'] = ['my-openvswitch', 'my-other-openvswitch']
    node.set['openstack']['network']['platform']['neutron_openvswitch_agent_packages'] = ['my-openvswitch-agent', 'my-other-openvswitch-agent']
    chef_run.converge 'openstack-network::openvswitch'

    %w{my-openvswitch my-other-openvswitch my-openvswitch-agent my-other-openvswitch-agent}.each do |pkg|
      expect(chef_run).to install_package(pkg)
    end
  end

  it 'creates execute resource when openvswitch-datasource-dkms package is being installed' do
    resource = @chef_run.find_resource('execute', @kmod_command).to_hash

    expect(resource).to include(
      action: [:nothing],
      command: @kmod_command
    )
  end

  it 'does not create execute resource when openvswitch-datasource-dkms package is not being installed' do
    chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
    node = chef_run.node
    node.set['openstack']['compute']['network']['service_type'] = 'neutron'
    node.set['openstack']['network']['platform']['neutron_openvswitch_packages'] = ['my-openvswitch', 'my-other-openvswitch']
    chef_run.converge 'openstack-network::openvswitch'

    resource = chef_run.find_resource('execute', @kmod_command)
    expect(resource).to eq(nil)

  end

  it 'notifies :run to the force-reload-kmod execute resource when openvswitch-datapath-dkms is installed' do
    expect(@chef_run.package('openvswitch-datapath-dkms')).to notify("execute[#{@kmod_command}]").to(:run).immediately
  end

  describe 'ovs-dpctl-top' do
    before do
      @file = @chef_run.cookbook_file('ovs-dpctl-top')
    end

    it 'creates the ovs-dpctl-top file' do
      expect(@chef_run).to create_cookbook_file('/usr/bin/ovs-dpctl-top')
    end

    it 'has the proper owner' do
      expect(@file.owner).to eq('root')
      expect(@file.group).to eq('root')
    end

    it 'has the proper mode' do
      expect(sprintf('%o', @file.mode)).to eq '755'
    end

    it 'has the proper interpreter line' do
      expect(@chef_run).to render_file(@file.name).with_content(
        %r{^#!\/usr\/bin\/env python}
      )
    end
  end

  describe 'ovs_neutron_plugin.ini' do
    before do
      @file = @chef_run.template '/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini'
    end

    it 'has proper owner' do
      expect(@file.owner).to eq('neutron')
      expect(@file.group).to eq('neutron')
    end

    it 'has proper modes' do
      expect(sprintf('%o', @file.mode)).to eq '644'
    end

    it 'uses default network_vlan_range' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        /^network_vlan_ranges =/)
    end

    it 'uses default tunnel_id_ranges' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        /^tunnel_id_ranges =/)
    end

    it 'uses default integration_bridge' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'integration_bridge = br-int')
    end

    it 'uses default tunnel bridge' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'tunnel_bridge = br-tun')
    end

    it 'uses default int_peer_patch_port' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        /^int_peer_patch_port =/)
    end

    it 'uses default tun_peer_patch_port' do
      expect(@chef_run).not_to render_file(@file.name).with_content(
        /^tun_peer_patch_port =/)
    end

    it 'it has firewall driver' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver')
    end

    it 'it uses local_ip from eth0 when local_ip_interface is set' do
      expect(@chef_run).to render_file(@file.name).with_content('local_ip = 10.0.0.3')
    end

    it 'sets sqlalchemy attributes' do
      expect(@chef_run).to render_file(@file.name).with_content(
        'sql_dbpool_enable = False')
      expect(@chef_run).to render_file(@file.name).with_content(
        'sql_min_pool_size = 1')
      expect(@chef_run).to render_file(@file.name).with_content(
        'sql_max_pool_size = 5')
      expect(@chef_run).to render_file(@file.name).with_content(
        'sql_idle_timeout = 3600')
    end
  end
end
