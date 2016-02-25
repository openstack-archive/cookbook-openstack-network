# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: opensvswitch
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

include_recipe 'openstack-network::ml2_openvswitch'

plugin_file_path = File.join(
  node['openstack']['network']['plugins']['openvswitch']['path'],
  node['openstack']['network']['plugins']['openvswitch']['filename']
)

platform_options = node['openstack']['network']['platform']
platform_options['neutron_openvswitch_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

service 'neutron-openvswitch-switch' do
  service_name platform_options['neutron_openvswitch_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, "template[#{plugin_file_path}]"
end
