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

# This will copy recursively all the files in
# /files/default/etc/quantum/rootwrap.d
remote_directory "/etc/quantum/rootwrap.d" do
  files_owner node["openstack"]["network"]["platform"]["user"]
  files_group node["openstack"]["network"]["platform"]["group"]
  files_mode 00700
end

directory "/etc/quantum/plugins" do
  owner node["openstack"]["network"]["platform"]["user"]
  group node["openstack"]["network"]["platform"]["group"]
  mode 00700
end

platform_options["quantum_dhcp_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

service "quantum-dhcp-agent" do
  service_name platform_options["quantum_dhcp_agent_service"]
  supports :status => true, :restart => true

  action :enable
end

# Some plugins have DHCP functionality, so we install the plugin
# Python package and include the plugin-specific recipe here...
main_plugin = node["openstack"]["network"]["interface_driver"].split('.').last.downcase

package platform_options["quantum_plugin_package"].gsub("%plugin%", main_plugin) do
  action :install
end

include_recipe "openstack-network::#{main_plugin}"

execute "quantum-dhcp-setup --plugin #{main_plugin}" do
  only_if { platform?(%w(fedora redhat centos)) } # :pragma-foodcritic: ~FC024 - won't fix this
end

template "/etc/quantum/dhcp_agent.ini" do
  source "dhcp_agent.ini.erb"
  owner node["openstack"]["network"]["platform"]["user"]
  group node["openstack"]["network"]["platform"]["group"]
  mode   00644

  notifies :restart, "service[quantum-dhcp-agent]", :immediately
end
