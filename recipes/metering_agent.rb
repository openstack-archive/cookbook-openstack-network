# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: metering_agent
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

platform_options = node['openstack']['network']['platform']

platform_options['neutron_metering_agent_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
end

service_config = merge_config_options 'network_metering'
template node['openstack']['network_metering']['config_file'] do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  variables(
    service_config: service_config
  )
  action :create
end

service 'neutron-metering-agent' do
  service_name platform_options['neutron_metering_agent_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, [
    'template[/etc/neutron/neutron.conf]',
    "template[#{node['openstack']['network_metering']['config_file']}]"
  ]
end
