# Encoding: utf-8
#
# Cookbook:: openstack-network
# Recipe:: lbaas
#
# Copyright:: 2013, Mirantis IT
# Copyright:: 2020, Oregon State University
# Copyright:: 2020, x-ion GmbH
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

include_recipe 'openstack-network'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

platform_options = node['openstack']['network']['platform']
package platform_options['neutron_lbaas_packages'] do
  options platform_options['package_overrides']
  action :upgrade
end

agent_config = merge_config_options 'network_lbaas_agent'

template node['openstack']['network_lbaas_agent']['config_file'] do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode '640'
  variables(
    service_config: agent_config
  )
  notifies :restart, 'service[neutron-lb-agent]', :delayed
end

service 'neutron-lb-agent' do
  service_name platform_options['neutron_lb_agent_service']
  supports status: true, restart: true
  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]', :delayed
  subscribes :restart, "template[#{node['openstack']['network_lbaas']['config_file']}]", :delayed
end
