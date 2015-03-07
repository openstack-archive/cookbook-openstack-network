# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: opensvswitch
#
# Copyright 2013, AT&T
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

require 'uri'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

include_recipe 'openstack-network'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

if platform_family?('debian')

  # obtain kernel version for kernel header
  # installation on ubuntu and debian
  kernel_ver = node['kernel']['release']
  package "linux-headers-#{kernel_ver}" do
    options platform_options['package_overrides']
    action :upgrade
  end

end

if node['openstack']['network']['openvswitch']['use_source_version']
  if node['lsb'] && node['lsb']['codename'] == 'precise'
    include_recipe 'openstack-network::build_openvswitch_source'
  end
else
  platform_options['neutron_openvswitch_packages'].each do |pkg|
    package pkg do
      options platform_options['package_overrides']
      action :upgrade
    end
  end
end

if platform_family?('debian')

  # NOTE:(mancdaz):sometimes the openvswitch module does not get reloaded
  # properly when openvswitch-datapath-dkms recompiles it.  This ensures
  # that it does

  begin
    if resources('package[openvswitch-datapath-dkms]')
      execute '/usr/share/openvswitch/scripts/ovs-ctl force-reload-kmod' do
        action :nothing
        subscribes :run, resources('package[openvswitch-datapath-dkms]'), :immediately
      end
    end
  rescue Chef::Exceptions::ResourceNotFound # rubocop:disable HandleExceptions
  end

end

service 'neutron-openvswitch-switch' do
  service_name platform_options['neutron_openvswitch_service']
  supports status: true, restart: true
  action [:enable, :start]
end

if node.run_list.expand(node.chef_environment).recipes.include?('openstack-network::server')
  service 'neutron-server' do
    service_name platform_options['neutron_server_service']
    supports status: true, restart: true
    action :nothing
  end
end

platform_options['neutron_openvswitch_agent_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
end

directory '/etc/neutron/plugins/openvswitch' do
  recursive true
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00700
  only_if { platform_family?('rhel') }
end

openvswitch_endpoint = endpoint 'network-openvswitch'
tunnel_types = node['openstack']['network']['openvswitch']['tunnel_types']
l2_population = 'False'
enable_distributed_routing = 'False'
if ['auto', 'true', true].include?(node['openstack']['network']['l3']['router_distributed'])
  tunnel_types = 'gre, vxlan'
  l2_population = 'True'
  enable_distributed_routing = 'True'
end
template '/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini' do
  source 'plugins/openvswitch/ovs_neutron_plugin.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
  variables(
    local_ip: openvswitch_endpoint.host,
    tunnel_types: tunnel_types,
    l2_population: l2_population,
    enable_distributed_routing: enable_distributed_routing
  )
  only_if { platform_family?('rhel') }
end

service 'neutron-plugin-openvswitch-agent' do
  service_name platform_options['neutron_openvswitch_agent_service']
  supports status: true, restart: true
  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]'
  if platform_family?('rhel')
    subscribes :restart, 'template[/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini]'
  end
end

unless ['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin)
  int_bridge = node['openstack']['network']['openvswitch']['integration_bridge']
  execute 'create internal network bridge' do
    ignore_failure true
    command "ovs-vsctl add-br #{int_bridge}"
    action :run
    not_if "ovs-vsctl br-exists #{int_bridge}"
    notifies :restart, 'service[neutron-plugin-openvswitch-agent]', :delayed
  end
end

unless ['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin)
  tun_bridge = node['openstack']['network']['openvswitch']['tunnel_bridge']
  execute 'create tunnel network bridge' do
    ignore_failure true
    command "ovs-vsctl add-br #{tun_bridge}"
    action :run
    not_if "ovs-vsctl br-exists #{tun_bridge}"
    notifies :restart, 'service[neutron-plugin-openvswitch-agent]', :delayed
  end
end

unless ['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin)
  unless node['openstack']['network']['openvswitch']['bridge_mapping_interface'].to_s.empty?
    ext_bridge_mapping = node['openstack']['network']['openvswitch']['bridge_mapping_interface']
    ext_bridge, ext_bridge_iface = ext_bridge_mapping.split(':')
    execute 'create data network bridge' do
      command "ovs-vsctl add-br #{ext_bridge} -- add-port #{ext_bridge} #{ext_bridge_iface}"
      action :run
      not_if "ovs-vsctl br-exists #{ext_bridge}"
      only_if "ip link show #{ext_bridge_iface}"
      notifies :restart, 'service[neutron-plugin-openvswitch-agent]', :delayed
    end
  end
end

if [true, 'true', 'auto'].include?(node['openstack']['network']['l3']['router_distributed'])
  if !node['recipes'].include?('openstack-network::server') && node['recipes'].include?('openstack-compute::compute')
    include_recipe 'openstack-network::l3_agent'
  end
end
