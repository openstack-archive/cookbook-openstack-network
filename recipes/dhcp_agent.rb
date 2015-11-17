# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: dhcp_agent
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

platform_options = node['openstack']['network']['platform']

platform_options['neutron_dhcp_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

# TODO: (jklare) this should be refactored and probably pull in the some dnsmasq
# cookbook to do the proper configuration
template '/etc/neutron/dnsmasq.conf' do
  source 'dnsmasq.conf.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
end

service_config = merge_config_options 'network_dhcp'
template node['openstack']['network_dhcp']['config_file'] do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
  variables(
    service_config: service_config
  )
end

# TODO: (jklare) this should be refactored and probably pull in the some dnsmasq
# cookbook to do the proper configuration
case node['platform']
when 'centos'
  if node['platform_version'].to_f < 7.1
    dnsmasq_file = "#{Chef::Config[:file_cache_path]}/#{node['openstack']['network']['dnsmasq']['rpm_version']}"
    remote_file dnsmasq_file do
      source node['openstack']['network']['dnsmasq']['rpm_source']
      not_if { ::File.exist?(dnsmasq_file) || node['openstack']['network']['dnsmasq']['rpm_version'].to_s.empty? }
    end
    rpm_package 'dnsmasq' do
      source dnsmasq_file
      action :install
      not_if { node['openstack']['network']['dnsmasq']['rpm_version'].to_s.empty? }
    end
  end
end

service 'neutron-dhcp-agent' do
  service_name platform_options['neutron_dhcp_agent_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, [
    'template[/etc/neutron/neutron.conf]',
    'template [/etc/neutron/dnsmasq.conf]',
    "template[#{node['openstack']['network_dhcp']['config_file']}]",
    'rpm_package[dnsmasq]'
  ]
end
