#
# Cookbook Name:: openstack-network
# Recipe:: server
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

require "uri"

class ::Chef::Recipe
  include ::Openstack
end

main_plugin = node["openstack"]["network"]["plugins"].first.downcase
core_plugin = node["openstack"]["network"]["core_plugin"]

if node["openstack"]["network"]["syslog"]["use"]
  include_recipe "openstack-common::logging"
end

platform_options = node["openstack"]["network"]["platform"]

platform_options["nova_network_packages"].each do |pkg|
  package pkg do
    action :purge
  end
end

platform_options["mysql_python_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

platform_options["quantum_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

platform_options["quantum_l3_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

platform_options["quantum_dhcp_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

service "quantum-server" do
  service_name platform_options["quantum_server_service"]
  supports :status => true, :restart => true

  action :enable
end

service "quantum-l3-agent" do
  service_name platform_options["quantum_l3_agent_service"]
  supports :status => true, :restart => true

  # The providers below do not use the generic L3 agent...
  not_if { ["nicira", "plumgrid", "bigswitch"].include?(main_plugin) }
  action :enable
end

service "quantum-dhcp-agent" do
  service_name platform_options["quantum_dhcp_agent_service"]
  supports :status => true, :restart => true
  action :enable
end

service "quantum-metadata-agent" do
  service_name platform_options["quantum_metadata_agent_service"]
  supports :status => true, :restart => true

  action :enable
end

# This will copy recursively all the files in
# /files/default/etc/quantum/rootwrap.d
remote_directory "/etc/quantum/rootwrap.d" do
  files_owner node["openstack"]["network"]["user"]
  files_group node["openstack"]["network"]["group"]
  files_mode 00700
end

directory "/etc/quantum/plugins" do
  owner node["openstack"]["network"]["user"]
  group node["openstack"]["network"]["group"]
  mode 00700
end

directory ::File.dirname node["openstack"]["network"]["api"]["auth"]["cache_dir"] do
  owner node["openstack"]["network"]["user"]
  group node["openstack"]["network"]["group"]
  mode 00700

  only_if { node["openstack"]["auth"]["strategy"] == "pki" }
end

template "/etc/quantum/policy.json" do
  source "policy.json.erb"
  owner node["openstack"]["network"]["user"]
  group node["openstack"]["network"]["group"]
  mode 00644

  notifies :restart, "service[quantum-server]", :immediately
end

rabbit_server_role = node["openstack"]["network"]["rabbit_server_chef_role"]
rabbit_info = config_by_role rabbit_server_role, "queue"
rabbit_user = node["openstack"]["network"]["rabbit"]["username"]
rabbit_vhost = node["openstack"]["network"]["rabbit"]["vhost"]
rabbit_pass = user_password "rabbit"

identity_endpoint = endpoint "identity-api"
auth_uri = ::URI.decode identity_endpoint.to_s

db_user = node["openstack"]["network"]["db"]["username"]
db_pass = db_password "quantum"
sql_connection = db_uri("network", db_user, db_pass)

api_endpoint = endpoint "network-api"
service_pass = service_password "quantum"
service_tenant_name = node["openstack"]["network"]["service_tenant_name"]
service_user = node["openstack"]["network"]["service_user"]

if node["openstack"]["network"]["api"]["bind_interface"].nil?
  bind_address = api_endpoint.host
else
  bind_address = node["network"]["ipaddress_#{node["openstack"]["network"]["api"]["bind_interface"]}"]
end

# Here is where we set up the appropriate plugin INI files
# for the L2 and L3 drivers...

# Install the plugin's Python package
node["openstack"]["network"]["plugins"].each do |pkg|
  plugin_fmt = platform_options["quantum_plugin_package"]
  pkg = plugin_fmt.gsub("%plugin%", pkg)
  package pkg do
    action :install
  end
end

begin
  include_recipe "openstack-network::#{main_plugin}"
rescue Chef::Exceptions::RecipeNotFound
   Chef::Log.warn "Could not find recipe openstack-network::#{main_plugin} for inclusion"
end

template "/etc/quantum/quantum.conf" do
  source "quantum.conf.erb"
  owner node["openstack"]["network"]["user"]
  group node["openstack"]["network"]["group"]
  mode   00644
  variables(
    :bind_address => bind_address,
    :bind_port => api_endpoint.port,
    :rabbit_ipaddress => rabbit_info["host"],
    :rabbit_user => rabbit_user,
    :rabbit_password => rabbit_pass,
    :rabbit_port => rabbit_info["port"],
    :rabbit_virtual_host => rabbit_vhost,
    :core_plugin => core_plugin
  )

  notifies :restart, "service[quantum-server]", :immediately
end

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner node["openstack"]["network"]["user"]
  group node["openstack"]["network"]["group"]
  mode   00644
  variables(
    "identity_endpoint" => identity_endpoint,
    "service_pass" => service_pass
  )

  notifies :restart, "service[quantum-server]", :immediately
end

directory "/var/cache/quantum" do
  owner "quantum"
  group "quantum"
  mode 00700
end

