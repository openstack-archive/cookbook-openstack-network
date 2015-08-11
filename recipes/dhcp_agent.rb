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

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

include_recipe 'openstack-network'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

platform_options['neutron_dhcp_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

service 'neutron-dhcp-agent' do
  service_name platform_options['neutron_dhcp_agent_service']
  supports status: true, restart: true

  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]'
end

# Some plugins have DHCP functionality, so we install the plugin
# Python package and include the plugin-specific recipe here...
package platform_options['neutron_plugin_package'].gsub('%plugin%', main_plugin) do
  options platform_options['package_overrides']
  action :upgrade
  # plugins are installed by the main openstack-neutron package on SUSE
  not_if { platform_family? 'suse' }
end

template '/etc/neutron/dnsmasq.conf' do
  source 'dnsmasq.conf.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
  notifies :restart, 'service[neutron-dhcp-agent]', :delayed
end

template '/etc/neutron/dhcp_agent.ini' do
  source 'dhcp_agent.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
  notifies :restart, 'service[neutron-dhcp-agent]', :immediately
end

case node['platform']
when 'centos'
  if node['platform_version'].to_f < 7.1

    dnsmasq_file = "#{Chef::Config[:file_cache_path]}/#{node['openstack']['network']['dhcp']['dnsmasq_rpm_version']}"

    remote_file dnsmasq_file do
      source node['openstack']['network']['dhcp']['dnsmasq_rpm_source']
      not_if { ::File.exist?(dnsmasq_file) || node['openstack']['network']['dhcp']['dnsmasq_rpm_version'].to_s.empty? }
    end

    rpm_package 'dnsmasq' do
      source dnsmasq_file
      action :install
      notifies :restart, 'service[neutron-dhcp-agent]', :immediately
      not_if { node['openstack']['network']['dhcp']['dnsmasq_rpm_version'].to_s.empty? }
    end
  end
end
