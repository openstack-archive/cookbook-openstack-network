# Encoding: utf-8
#
# Cookbook:: openstack-network
# Recipe:: server
#
# Copyright:: 2013, AT&T
# Copyright:: 2013, SUSE Linux GmbH
# Copyright:: 2020, Oregon State University
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

template '/etc/default/neutron-server' do
  source 'neutron-server.erb'
  owner 'root'
  group 'root'
  mode '644'
  variables(
    core_plugin_config: node['openstack']['network']['core_plugin_config_file']
  )
  only_if { platform_family?('debian') }
end

platform_options = node['openstack']['network']['platform']

package platform_options['neutron_server_packages'] do
  options platform_options['package_overrides']
  action :upgrade
end

db_type = node['openstack']['db']['network']['service_type']
package node['openstack']['db']['python_packages'][db_type] do
  options platform_options['package_overrides']
  action :upgrade
end

if node['openstack']['network']['policyfile_url']
  remote_file '/etc/neutron/policy.json' do
    source node['openstack']['network']['policyfile_url']
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode '644'
  end
end

if node['openstack']['network_lbaas']['enabled']
  # neutron-lbaas-agent may not running on network node, but on network
  # node, neutron-server still need neutron_lbaas module when loading
  # plugin if lbaas is list in service_plugins. In this case, we don't
  # need include balance recipe for network node, but we need make sure
  # neutron lbaas python packages get installed on network node before
  # neutron-server start/restart, when lbaas is enabled. Otherwise
  # neutron-server will crash for couldn't find lbaas plugin when
  # invoking plugins from service_plugins.
  package platform_options['neutron_lbaas_python_dependencies'] do
    options platform_options['package_overrides']
    action :upgrade
  end
end

# Migrate network database to latest version
include_recipe 'openstack-network::db_migration'
plugin_templates = []
node['openstack']['network']['plugins'].each_value.to_s do |plugin|
  plugin_templates << "template[#{File.join(plugin['path'], plugin['filename'])}]"
end

service 'neutron-server' do
  service_name platform_options['neutron_server_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, [
    plugin_templates,
    'template[/etc/neutron/neutron.conf]',
    'remote_file[/etc/neutron/policy.json]',
  ].flatten
end

include_recipe 'openstack-network::identity_registration'
