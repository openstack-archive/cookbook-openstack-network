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

include_recipe 'openstack-network'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

platform_options = node['openstack']['network']['platform']

platform_options['neutron_l3_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

service_config = merge_config_options 'network_l3'
template node['openstack']['network_l3']['config_file'] do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 0o0640
  variables(
    service_config: service_config
  )
  # Not restart l3 agent to avoid synchronization problem, when vpn agent is enabled.
  unless node['openstack']['network_vpnaas']['enabled']
    notifies :restart, 'service[neutron-l3-agent]'
  end
end

# See http://docs.openstack.org/admin-guide-cloud/content/section_adv_cfg_l3_agent.html

service 'neutron-l3-agent' do
  service_name platform_options['neutron_l3_agent_service']
  supports status: true, restart: true
  # As l3 and vpn agents are both working based on l3 bisic strategy, and there will be
  # potential synchronization problems when vpn and l3 agents both running in network node.
  # So if the vpn agent is enabled, we should stop and disable the l3 agent.
  if node['openstack']['network_vpnaas']['enabled']
    action [:stop, :disable]
  else
    action [:enable, :start]
    subscribes :restart, [
      'template[/etc/neutron/neutron.conf]',
      "template[#{node['openstack']['network_fwaas']['config_file']}]",
    ]
  end
end
