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

include_recipe 'openstack-network::common'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']

platform_options['neutron_server_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

# Migrate network database
# If the database has never migrated, make the current version of alembic_version to Icehouse,
# else migrate the database to latest version.
# The node['openstack']['network']['plugin_config_file'] attribute is set in the common.rb recipe

bash 'migrate network database' do
  plugin_config_file = node['openstack']['network']['plugin_config_file']
  db_stamp = node['openstack']['network']['db_stamp']
  migrate_command = "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
current_version_line=`#{migrate_command} current 2>&1 | tail -n 1`
# determine if the $current_version_line ends with ": None"
if [[ $current_version_line == *:\\ None ]]; then
  #{migrate_command} stamp #{db_stamp}
else
  #{migrate_command} upgrade head
fi
EOF
end

service 'neutron-server' do
  service_name platform_options['neutron_server_service']
  supports status: true, restart: true
  action :enable
end

cookbook_file 'neutron-ha-tool' do
  source 'neutron-ha-tool.py'
  path node['openstack']['network']['neutron_ha_cmd']
  owner 'root'
  group 'root'
  mode 00755
end

if node['openstack']['network']['neutron_ha_cmd_cron']
  # ensure period checks are offset between multiple l3 agent nodes
  # and assumes splay will remain constant (i.e. based on hostname)
  # Generate a uniformly distributed unique number to sleep.
  checksum   = Digest::MD5.hexdigest(node['fqdn'] || 'unknown-hostname')
  splay = node['chef_client']['splay'].to_i || 3000
  sleep_time = checksum.to_s.hex % splay

  cron 'neutron-ha-healthcheck' do
    minute node['openstack']['network']['cron_l3_healthcheck']
    command "sleep #{sleep_time} ; . /root/openrc && #{node["openstack"]["network"]["neutron_ha_cmd"]} --l3-agent-migrate > /dev/null 2>&1"
  end

  cron 'neutron-ha-replicate-dhcp' do
    minute node['openstack']['network']['cron_replicate_dhcp']
    command "sleep #{sleep_time} ; . /root/openrc && #{node["openstack"]["network"]["neutron_ha_cmd"]} --replicate-dhcp > /dev/null 2>&1"
  end
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
