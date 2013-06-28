#
# Cookbook Name:: openstack-network
# Recipe:: opensvswitch
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

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end

platform_options = node["openstack"]["network"]["platform"]

# discover database attributes
db_user = node["openstack"]["network"]["db"]["username"]
db_pass = db_password "quantum"
sql_connection = db_uri("network", db_user, db_pass)

bash "installing linux headers to compile openvswitch module" do
  only_if { platform?(%w(ubuntu debian)) } # :pragma-foodcritic: ~FC024 - won't fix this
  code <<-EOH
    apt-get install -y linux-headers-`uname -r`
  EOH
end

platform_options["quantum_openvswitch_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

service "quantum-openvswitch-switch" do
  service_name platform_options["quantum_openvswitch_service"]
  supports :status => true, :restart => true
  action :enable
end

execute "quantum-node-setup --plugin openvswitch" do
  only_if { platform?(%w(fedora redhat centos)) } # :pragma-foodcritic: ~FC024 - won't fix this
end

if node.run_list.expand(node.chef_environment).recipes.include?("openstack-network::server")
  template "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini" do
    source "plugins/openvswitch/ovs_quantum_plugin.ini.erb"
    owner node["openstack"]["network"]["platform"]["user"]
    group node["openstack"]["network"]["platform"]["group"]
    mode 00644
    variables(
      :sql_connection => sql_connection
    )
    notifies :restart, "service[quantum-server]", :immediately
  end
end
