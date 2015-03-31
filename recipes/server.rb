# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: server
#
# Copyright 2013, AT&T
# Copyright 2013, SUSE Linux GmbH
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

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

include_recipe 'openstack-network'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']

platform_options['neutron_server_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

# Migrate network database to latest version
include_recipe 'openstack-network::db_migration'

service 'neutron-server' do
  service_name platform_options['neutron_server_service']
  supports status: true, restart: true
  action [:enable, :start]
end

# the default SUSE initfile uses this sysconfig file to determine the
# neutron plugin to use
template '/etc/sysconfig/neutron' do
  only_if { platform_family? 'suse' }
  source 'neutron.sysconfig.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables(
    plugin_conf: node['openstack']['network']['plugin_conf_map'][core_plugin.split('.').last.downcase]
  )
  notifies :restart, 'service[neutron-server]'
end
