# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: _bridge_config_example
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

# This recipe is intended as an example of just one possible bridge
# configuration for ml2 and should not be used as is in production. The
# openstack-network cookbook tries to provide all the basic  features to deploy
# the neutron services, but can not include all possible network and bridge
# configurations out there. To use the openstack-network cookbook in production,
# please create a wrapper to configure your network interfaces and adapt the
# configs accordingly. You should find fitting examples given below.

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

# set and get name for tun interface (can be overwritten in the environment,
# like shown for the multi-node scenario in the openstack-chef-repo)
node.default['openstack']['network']['tun_network_bridge_interface'] = 'eth-tun'
tun_interface = node['openstack']['network']['tun_network_bridge_interface']

# Helper for creating dummy interfaces for ovs bridges on jenkins test nodes and
# in testing vagrant boxes.
# The created interfaces do not work for real network traffic, but are needed to
# test the bridge creation and usage in the recipes.
# This needs to be done during compile time to ensure that the address_for
# method used lateron works
execute 'create eth-ext dummy interface' do
  command 'ip link add eth-ext type dummy;'\
    'ip link set dev eth-ext up'
  not_if 'ip link show | grep eth-ext'
end.run_action(:run)

execute 'create eth-vlan dummy interface' do
  command 'ip link add eth-vlan type dummy;'\
    'ip link set dev eth-vlan up'
  not_if 'ip link show | grep eth-vlan'
end.run_action(:run)

execute "create #{tun_interface} dummy interface" do
  command "ip link add #{tun_interface} type dummy;"\
    "ip link set dev #{tun_interface} up;"\
    "ip addr add 10.0.0.201/24 dev #{tun_interface}"
  not_if "ip link show | grep #{tun_interface}"
end.run_action(:run)

# reload node attributes to get configuration for newly created dummy interfaces
ohai('reload').run_action(:reload)

# set all the needed attributes according to the dummy interfaces added above
# vlan bridge
node.default['openstack']['network']['vlan_network_bridge_interface'] = 'eth-vlan'
node.default['openstack']['network']['plugins']['openvswitch']['conf']
.[]('OVS')['bridge_mappings'] = 'vlan:br-vlan,external:br-ex'

# external bridge
node.default['openstack']['network_l3']['external_network_bridge_interface'] = 'eth-ext'

# tunnel bridge
node.default['openstack']['network']['plugins']['openvswitch']['conf']
.[]('OVS')['tunnel_bridge'] = 'br-tun'
node.default['openstack']['network']['plugins']['openvswitch']['conf']
.[]('OVS')['local_ip'] =
  address_for(tun_interface)
node.default['openstack']['network']['plugins']['openvswitch']['conf']
.[]('AGENT')['tunnel_types'] = 'gre,vxlan'

# ovs security groups
node.default['openstack']['network']['plugins']['openvswitch']['conf']
.[]('SECURITYGROUP')['firewall_driver'] =
  'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver'

# define variables for bridge definitions below
ex_bridge_iface = node['openstack']['network_l3']['external_network_bridge_interface']
vlan_bridge_iface = node['openstack']['network']['vlan_network_bridge_interface']
tun_bridge = node['openstack']['network']['plugins']['openvswitch']['conf']
.[]('OVS')['tunnel_bridge']

# get the bridge names from the ovs bridge_mappings
mappings = node['openstack']['network']['plugins']['openvswitch']['conf']
.[]('OVS')['bridge_mappings'].split(',')
vlan_bridge = mappings.find { |mapping| mapping.split(':').first == 'vlan' }.split(':').last
ex_bridge = mappings.find { |mapping| mapping.split(':').first == 'external' }.split(':').last

execute 'create external network bridge' do
  command "ovs-vsctl --may-exist add-br #{ex_bridge}"
  action :run
end

execute 'create external network bridge port' do
  command "ovs-vsctl --may-exist add-port #{ex_bridge} #{ex_bridge_iface}"
  action :run
end

execute 'create vlan network bridge' do
  command "ovs-vsctl --may-exist add-br #{vlan_bridge}"
  action :run
end

execute 'create vlan network bridge port' do
  command "ovs-vsctl --may-exist add-port #{vlan_bridge} #{vlan_bridge_iface}"
  action :run
end

execute 'create tunnel network bridge' do
  command "ovs-vsctl --may-exist add-br #{tun_bridge}"
  action :run
end
