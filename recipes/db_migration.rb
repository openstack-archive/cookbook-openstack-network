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

plugin_config_file = node['openstack']['network']['core_plugin_config_file']
timeout = node['openstack']['network']['dbsync_timeout']
# The node['openstack']['network']['plugin_config_file'] attribute is set in the default.rb recipe
bash 'migrate network database' do
  timeout timeout
  migrate_command = 'neutron-db-manage --config-file /etc/neutron/neutron.conf'
  code <<-EOF
#{migrate_command} upgrade heads
EOF
end

# Only if the vpnaas is enabled, migrate the database.
bash 'migrate vpnaas database' do
  only_if { node['openstack']['network_vpnaas']['enabled'] }
  timeout timeout
  migrate_command = "neutron-db-manage --subproject neutron-vpnaas --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade heads
EOF
end

# Only if the fwaas is enabled, migrate the database.
bash 'migrate fwaas database' do
  only_if { node['openstack']['network_fwaas']['enabled'] }
  timeout timeout
  migrate_command = "neutron-db-manage --subproject neutron-fwaas --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade heads
EOF
end

# Only if the lbaas is enabled, migrate the database.
bash 'migrate lbaas database' do
  only_if { node['openstack']['network_lbaas']['enabled'] }
  timeout timeout
  migrate_command = "neutron-db-manage --subproject neutron-lbaas --config-file /etc/neutron/neutron.conf --config-file #{plugin_config_file}"
  code <<-EOF
#{migrate_command} upgrade heads
EOF
end
