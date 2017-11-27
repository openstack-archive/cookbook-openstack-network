# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: default
#
# Copyright 2013, AT&T
# Copyright 2013-2014, SUSE Linux GmbH
# Copyright 2013-2014, IBM Corp.
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

require 'addressable'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

platform_options = node['openstack']['network']['platform']

if node['openstack']['network']['syslog']['use']
  include_recipe 'openstack-common::logging'
end

platform_options['neutron_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

db_type = node['openstack']['db']['network']['service_type']
node['openstack']['db']['python_packages'][db_type].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

directory '/var/cache/neutron' do
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 0o0700
  action :create
end

directory node['openstack']['network']['api']['auth']['cache_dir'] do
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 0o0700
  only_if { node['openstack']['auth']['strategy'] == 'pki' }
end

template '/etc/neutron/rootwrap.conf' do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 0o0644
  variables(
    service_config: node['openstack']['network']['rootwrap']['conf']
  )
end

if node['openstack']['mq']['service_type'] == 'rabbit'
  node.default['openstack']['network']['conf_secrets']['DEFAULT']['transport_url'] = rabbit_transport_url 'network'
end

identity_public_endpoint = public_endpoint 'identity'
auth_url = identity_public_endpoint.to_s

db_user = node['openstack']['db']['network']['username']
db_pass = get_password 'db', 'neutron'
bind_service = node['openstack']['bind_service']['all']['network']
bind_service_address = bind_address bind_service

# The auth_url in nova section follows auth_type
nova_auth_url = nil
case node['openstack']['network']['conf']['nova']['auth_type']
when 'password'
  nova_auth_url = auth_uri
when 'v2password'
  nova_auth_url = auth_uri_transform(identity_public_endpoint.to_s, 'v2.0')
when 'v3password'
  nova_auth_url = auth_uri_transform(identity_public_endpoint.to_s, 'v3.0')
end

node.default['openstack']['network']['conf'].tap do |conf|
  if node['openstack']['network']['syslog']['use']
    conf['DEFAULT']['log_config'] = '/etc/openstack/logging.conf'
  end
  conf['DEFAULT']['bind_host'] = bind_service_address
  conf['DEFAULT']['bind_port'] = bind_service['port']
  conf['nova']['auth_url'] = nova_auth_url if nova_auth_url
  conf['keystone_authtoken']['auth_url'] = auth_url
end

# define secrets that are needed in the neutron.conf.erb
node.default['openstack']['network']['conf_secrets'].tap do |conf_secrets|
  conf_secrets['database']['connection'] =
    db_uri('network', db_user, db_pass)
  conf_secrets['nova']['password'] =
    get_password 'service', 'openstack-compute'
  conf_secrets['keystone_authtoken']['password'] =
    get_password 'service', 'openstack-network'
end

# merge all config options and secrets to be used in the neutron.conf.erb
neutron_conf_options = merge_config_options 'network'

template '/etc/neutron/neutron.conf' do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 0o0640
  variables(
    service_config: neutron_conf_options
  )
end

# delete all secrets saved in the attribute
# node['openstack']['network']['conf_secrets'] after creating the neutron.conf
ruby_block "delete all attributes in node['openstack']['network']['conf_secrets']" do
  block do
    node.rm(:openstack, :network, :conf_secrets)
  end
end
