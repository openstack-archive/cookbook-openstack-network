# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: balancer
#
# Copyright 2013, Mirantis IT
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

# This recipe should be placed in the run_list of the node that
# runs the network server or network controller server.

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

[true, 'true', 'True'].include?(node['openstack']['network']['lbaas']['enabled']) || return

include_recipe 'openstack-network'

platform_options = node['openstack']['network']['platform']

platform_options['neutron_lb_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

template node['openstack']['network']['lbaas']['config_file'] do
  source 'services/neutron-lbaas/lbaas_agent.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  notifies :restart, 'service[neutron-lb-agent]', :delayed
end

service 'neutron-lb-agent' do
  service_name platform_options['neutron_lb_agent_service']
  supports status: true, restart: true
  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]', :delayed
end
