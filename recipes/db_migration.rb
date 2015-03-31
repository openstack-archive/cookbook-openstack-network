# encoding: UTF-8
#
# Cookbook Name:: openstack-network
# Recipe:: db_migration
#
# Copyright 2015, IBM Corp.
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

# The node['openstack']['network']['plugin_config_file'] attribute is set in the default.rb recipe
bash 'migrate network database' do
  timeout node['openstack']['network']['dbsync_timeout']
  plugin_config_file = node['openstack']['network']['plugin_config_file']
  migrate_command = "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade head
EOF
end

# Only if the vpnaas is enabled, migrate the database.
bash 'migrate vpnaas database' do
  only_if { [true, 'true', 'True'].include?(node['openstack']['network']['enable_vpn']) }
  timeout node['openstack']['network']['dbsync_timeout']
  plugin_config_file = node['openstack']['network']['plugin_config_file']
  migrate_command = "neutron-db-manage --service vpnaas --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade head
EOF
end

# Only if the fwaas is enabled, migrate the database.
bash 'migrate fwaas database' do
  only_if { [true, 'true', 'True'].include?(node['openstack']['network']['fwaas']['enabled']) }
  timeout node['openstack']['network']['dbsync_timeout']
  plugin_config_file = node['openstack']['network']['plugin_config_file']
  migrate_command = "neutron-db-manage --service fwaas --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade head
EOF
end

# Only if the lbaas is enabled, migrate the database.
bash 'migrate lbaas database' do
  only_if { [true, 'true', 'True'].include?(node['openstack']['network']['lbaas']['enabled']) }
  timeout node['openstack']['network']['dbsync_timeout']
  plugin_config_file = node['openstack']['network']['plugin_config_file']
  migrate_command = "neutron-db-manage --service lbaas --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade head
EOF
end
