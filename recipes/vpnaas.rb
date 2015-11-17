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

# VPN agent is based on L3 agent
include_recipe 'openstack-network::l3_agent'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

platform_options = node['openstack']['network']['platform']

# Install package dependencies according node's vpn_device_driver.
platform_options['vpn_device_driver_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

platform_options['neutron_vpnaas_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

platform_options['vpn_device_driver_services'].each do |svc|
  service 'vpn-device-driver-service' do
    service_name svc
    supports status: true, restart: true
    action :enable
  end
end

service_conf = merge_config_options 'network_vpnaas'
template node['openstack']['network_vpnaas']['config_file'] do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  variables(
    service_config: service_conf
  )
end

service 'neutron-vpn-agent' do
  service_name platform_options['neutron_vpn_agent_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, [
    'template[/etc/neutron/neutron.conf]',
    "template[#{node['openstack']['network_vpnaas']['config_file']}]"
  ]
end
