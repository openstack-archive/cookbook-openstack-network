# Encoding: utf-8
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

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

include_recipe 'openstack-network'

platform_options = node['openstack']['network']['platform']

platform_options['neutron_linuxbridge_agent_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

directory '/etc/neutron/plugins/linuxbridge' do
  recursive true
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00700
end

linuxbridge_endpoint = endpoint 'network-linuxbridge'
template '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini' do
  source 'plugins/linuxbridge/linuxbridge_conf.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
  variables(
    local_ip: linuxbridge_endpoint.host
  )
end

service 'neutron-plugin-linuxbridge-agent' do
  service_name platform_options['neutron_linuxbridge_agent_service']
  supports status: true, restart: true
  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]'
  subscribes :restart, 'template[/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini]'
end
