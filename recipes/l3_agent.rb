# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: l3_agent
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

include_recipe 'openstack-network'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
  include ::Utils
end

ruby_block 'query gateway external network uuid' do
  block do
    begin
      external_name = node['openstack']['network']['l3']['gateway_external_network_name']
      admin_user = node['openstack']['identity']['admin_user']
      admin_tenant = node['openstack']['identity']['admin_tenant_name']
      env = openstack_command_env admin_user, admin_tenant

      external_id = network_uuid 'net-external', 'name', external_name, env
      Chef::Log.error("gateway external network UUID for #{external_name} not found.") if external_id.nil?
      node.set['openstack']['network']['l3']['gateway_external_network_id'] = external_id
    rescue RuntimeError => e
      Chef::Log.error("Could not query UUID for network #{external_name}. Error was #{e.message}") unless external_id
    end
  end
  action :run
  only_if do
    (node['openstack']['network']['l3']['gateway_external_network_id'].nil? &&
     node['openstack']['network']['l3']['gateway_external_network_name'])
  end
end

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

platform_options['neutron_l3_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
    # The providers below do not use the generic L3 agent...
    not_if { ['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin) }
  end
end

service 'neutron-l3-agent' do
  service_name platform_options['neutron_l3_agent_service']
  supports status: true, restart: true
  # As l3 and vpn agents are both working based on l3 bisic strategy, and there will be
  # potential synchronization problems when vpn and l3 agents both running in network node.
  # So if the vpn agent is enabled, we should stop and disable the l3 agent.
  if node['openstack']['network']['enable_vpn']
    action [:stop, :disable]
  else
    action :enable
    subscribes :restart, 'template[/etc/neutron/neutron.conf]'
  end
end

agent_mode = 'legacy'
if [true, 'true', 'auto'].include?(node['openstack']['network']['l3']['router_distributed'])
  if recipe_included? 'openstack-network::server'
    agent_mode = 'dvr_snat'
  elsif recipe_included? 'openstack-compute::compute'
    agent_mode = 'dvr'
  end
end

template '/etc/neutron/l3_agent.ini' do
  source 'l3_agent.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  variables(
    agent_mode: agent_mode
  )
  # Not restart l3 agent to avoid synchronization problem, when vpn agent is enabled.
  unless node['openstack']['network']['enable_vpn']
    notifies :restart, 'service[neutron-l3-agent]', :immediately
  end
end

# As the fwaas package will be installed anyway, configure its config-file attributes following environment.
template node['openstack']['network']['fwaas']['config_file'] do
  source 'services/neutron-fwaas/fwaas_driver.ini.erb'
  user node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  # Only restart vpn agent to avoid synchronization problem, when vpn agent is enabled.
  if node['openstack']['network']['enable_vpn']
    notifies :restart, 'service[neutron-vpn-agent]', :delayed
  else
    notifies :restart, 'service[neutron-l3-agent]', :immediately
  end
end

driver_name = node['openstack']['network']['interface_driver'].split('.').last
# See http://docs.openstack.org/admin-guide-cloud/content/section_adv_cfg_l3_agent.html
case driver_name
when 'OVSInterfaceDriver'
  ext_bridge = node['openstack']['network']['l3']['external_network_bridge']
  ext_bridge_iface = node['openstack']['network']['l3']['external_network_bridge_interface']
  unless ext_bridge.to_s.empty?
    execute 'create external network bridge' do
      command "ovs-vsctl add-br #{ext_bridge}"
      action :run
      not_if "ovs-vsctl br-exists #{ext_bridge}"
    end
    execute 'enable external_network_bridge_interface' do
      command "ip link set #{ext_bridge_iface} up && ovs-vsctl --may-exist add-port #{ext_bridge} #{ext_bridge_iface}"
      only_if "ip link show #{ext_bridge_iface}"
    end
  end
when 'BridgeInterfaceDriver'
  # TODO: Handle linuxbridge case
end
