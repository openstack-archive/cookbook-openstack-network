# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: metadata_agent
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

include_recipe 'openstack-network'

platform_options = node['openstack']['network']['platform']

# identity_endpoint = admin_endpoint 'identity'
metadata_secret = get_password 'token', node['openstack']['network_metadata']['secret_name']
# compute_metadata_api = internal_endpoint 'compute-metadata-api'

platform_options['neutron_metadata_agent_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
end

node.default['openstack']['network_metadata']['conf_secrets'].tap do |conf|
  conf['DEFAULT']['metadata_proxy_shared_secret'] = metadata_secret
end

service_config = merge_config_options 'network_metadata'
template node['openstack']['network_metadata']['config_file'] do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 0o0644
  variables(
    service_config: service_config
  )
  action :create
end

# delete all secrets saved in the attribute
# node['openstack']['network_metadata']['conf_secrets'] after creating the neutron.conf
ruby_block 'delete all attributes in '\
  "node['openstack']['network_metadata']['conf_secrets']" do
  block do
    node.rm(:openstack, :network_metadata, :conf_secrets)
  end
end

service 'neutron-metadata-agent' do
  service_name platform_options['neutron_metadata_agent_service']
  supports status: true, restart: true
  action [:enable, :start]
  subscribes :restart, [
    'template[/etc/neutron/neutron.conf]',
    "template[#{node['openstack']['network_metadata']['config_file']}]",
  ]
end
