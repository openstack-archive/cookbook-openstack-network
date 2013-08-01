#
# Cookbook Name:: openstack-network
# Recipe:: linuxbridge
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

db_user = node["openstack"]["network"]["db"]["username"]
db_pass = db_password "quantum"
sql_connection = db_uri("network", db_user, db_pass)

service "quantum-server" do
  service_name node["openstack"]["network"]["platform"]["quantum_server_service"]
  supports :status => true, :restart => true
  action :nothing
end

template "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini" do
  source "plugins/linuxbridge/linuxbridge_conf.ini.erb"
  owner node["openstack"]["network"]["platform"]["user"]
  group node["openstack"]["network"]["platform"]["group"]
  mode 00644
  variables(
    :sql_connection => sql_connection
  )

  notifies :restart, "service[quantum-server]", :immediately
end

# Ubuntu packaging currently does not update the quantum init script to point to
# linuxbridge config file. Manual update /etc/default/quantum-server is required.
template "/etc/default/quantum-server" do
  source "quantum-server.erb"
  owner node["openstack"]["network"]["platform"]["user"]
  group node["openstack"]["network"]["platform"]["group"]
  mode   00600
  variables(
    :plugin_config => "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"
  )

  notifies :restart, "service[quantum-server]", :immediately
  only_if { platform? %w{ubuntu debian} }
end
