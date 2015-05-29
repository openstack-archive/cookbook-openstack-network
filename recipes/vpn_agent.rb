# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: vpn_agent
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
return unless node['openstack']['network']['enable_vpn']

use_namespaces = node['openstack']['network']['use_namespaces']
unless use_namespaces.downcase == 'true'
  fail "use_namespaces is #{use_namespaces}, and it must be True when using vpn agent"
end

# VPN agent is based on L3 agent
include_recipe 'openstack-network::l3_agent'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

# Install package dependencies according node's vpn_device_driver.
platform_options['vpn_device_driver_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
    only_if { node['openstack']['network']['vpn']['vpn_device_driver'].any? }
  end
end

platform_options['neutron_vpn_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
    # The vpn agent is depends on l3_agent and the providers below do not use the generic L3 agent.
    not_if { ['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin) }
  end
end

platform_options['vpn_device_driver_services'].each do |svc|
  service 'vpn-device-driver-service' do
    service_name svc
    supports status: true, restart: true
    action :enable
  end
end

service 'neutron-vpn-agent' do
  service_name platform_options['neutron_vpn_agent_service']
  supports status: true, restart: true
  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]'
end

template node['openstack']['network']['vpn']['config_file'] do
  source 'services/neutron-vpnaas/vpn_agent.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  notifies :restart, 'service[neutron-vpn-agent]', :immediately
end
