# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: ml2_opensvswitch
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

require 'uri'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

node.default['openstack']['network']['plugins']['ml2']['conf']['ml2']['mechanism_drivers'] = 'openvswitch'

platform_options = node['openstack']['network']['platform']
node.default['openstack']['network']['plugins']['openvswitch'].tap do |ovs|
  case node['platform_family']
  when 'fedora', 'rhel'
    ovs['path'] =
      '/etc/neutron/plugins/openvswitch'
    ovs['filename'] =
      'ovs_neutron_plugin.ini'
  when 'debian'
    ovs['path'] =
      '/etc/neutron/plugins/ml2'
    ovs['filename'] =
      'openvswitch_agent.ini'
  end
  ovs['conf']['DEFAULT']['integration_bridge'] = 'br-int'
  ovs['conf']['OVS']['tunnel_bridge'] = 'br-tun'
end

platform_options['neutron_openvswitch_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

plugin_file_path = File.join(
  node['openstack']['network']['plugins']['openvswitch']['path'],
  node['openstack']['network']['plugins']['openvswitch']['filename']
)

platform_options['neutron_openvswitch_agent_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
end

int_bridge =
  node['openstack']['network']['plugins']['openvswitch']['conf']
.[]('DEFAULT')['integration_bridge']
tun_bridge =
  node['openstack']['network']['plugins']['openvswitch']['conf']
.[]('OVS')['tunnel_bridge']
execute 'create internal network bridge' do
  ignore_failure true
  command "ovs-vsctl add-br #{int_bridge}"
  action :run
  not_if "ovs-vsctl br-exists #{int_bridge}"
end

include_recipe 'openstack-network::plugin_config'

service 'neutron-openvswitch-switch' do
  service_name platform_options['neutron_openvswitch_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, "template[#{plugin_file_path}]"
end

service 'neutron-plugin-openvswitch-agent' do
  service_name platform_options['neutron_openvswitch_agent_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, [
    'template[/etc/neutron/neutron.conf]',
    "template[#{plugin_file_path}]",
    'execute[create internal network bridge]',
    'execute[create tunnel network bridge]',
    'execute[create data network bridge]'
  ]
end

execute 'create tunnel network bridge' do
  ignore_failure true
  command "ovs-vsctl add-br #{tun_bridge}"
  action :run
  not_if "ovs-vsctl br-exists #{tun_bridge}"
end

if node['openstack']['network']['openvswitch']['bridge_mapping_interface']
  ext_bridge_mapping = node['openstack']['network']['openvswitch']['bridge_mapping_interface']
  ext_bridge, ext_bridge_iface = ext_bridge_mapping.split(':')
  execute 'create data network bridge' do
    command "ovs-vsctl add-br #{ext_bridge} -- add-port #{ext_bridge} #{ext_bridge_iface}"
    action :run
    not_if "ovs-vsctl br-exists #{ext_bridge}"
    only_if "ip link show #{ext_bridge_iface}"
  end
end
