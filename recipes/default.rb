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

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

# this is needed for querying the tenant_uuid of admin below
include_recipe 'openstack-identity::client'

require 'uri'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
  include ::Utils
end

# Make Openstack object available in Chef::Resource::RubyBlock
class ::Chef::Resource::RubyBlock
  include ::Openstack
end

platform_options = node['openstack']['network']['platform']

core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

role_match = role_included? 'os-network-server'

if node['openstack']['network']['syslog']['use']
  include_recipe 'openstack-common::logging'
end

platform_options['nova_network_packages'].each do |pkg|
  package pkg do
    action :purge
  end
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

# neutron-lbaas-agent may not running on network node, but on network node, neutron-server still need neutron_lbaas module
# when loading plugin if lbaas is list in service_plugins. In this case, we don't need include balance recipe for network node, but
# we need make sure neutron lbaas packages get installed on network ndoe before neutron-server start/restart, when lbaas is enabled.
# Otherwise neutron-server will crash for couldn't find lbaas plugin when invoking plugins from service_plugins.
platform_options['neutron_lb_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
    only_if { [true, 'true', 'True'].include?(node['openstack']['network']['lbaas']['enabled']) && role_match }
  end
end

# neutron-vpnaas-agent may not running on network node, but on network node, neutron-server still need neutron_vpnaas module
# when loading plugin if vpnaas is list in service_plugins. In this case, we don't need include vpn_agent recipe for network node, but
# we need make sure neutron vpnaas packages get installed on network node before neutron-server start/restart, when vpnaas is enabled.
# Otherwise neutron-server will crash for couldn't find vpnaas plugin when invoking plugins from service_plugins.
platform_options['neutron_vpn_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
    # The vpn agent depends on l3_agent, and providers nicira, plumgrid, bigswitch, will not use the generic l3_agent. So if we are using
    # these providers, vpn agent will not get supported, and we should not install related packages here.
    only_if { node['openstack']['network']['enable_vpn'] && role_match && !['nicira', 'plumgrid', 'bigswitch'].include?(main_plugin) }
  end
end

directory '/etc/neutron/plugins' do
  recursive true
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00700
  action :create
end

directory '/var/cache/neutron' do
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00700
  action :create
end

directory ::File.dirname node['openstack']['network']['api']['auth']['cache_dir'] do
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00700

  only_if { node['openstack']['auth']['strategy'] == 'pki' }
end

template '/etc/neutron/rootwrap.conf' do
  source 'rootwrap.conf.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00644
end

if node['openstack']['network']['policyfile_url']
  remote_file '/etc/neutron/policy.json' do
    source node['openstack']['network']['policyfile_url']
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end
end

mq_service_type = node['openstack']['mq']['network']['service_type']

if mq_service_type == 'rabbitmq'
  rabbit_hosts = rabbit_servers if node['openstack']['mq']['network']['rabbit']['ha']
  mq_password = get_password 'user', node['openstack']['mq']['network']['rabbit']['userid']
elsif mq_service_type == 'qpid'
  mq_password = get_password 'user', node['openstack']['mq']['network']['qpid']['username']
end

identity_endpoint = internal_endpoint 'identity-internal'
identity_admin_endpoint = admin_endpoint 'identity-admin'
auth_uri = ::URI.decode identity_endpoint.to_s

auth_uri = auth_uri_transform identity_endpoint.to_s, node['openstack']['network']['api']['auth']['version']
identity_uri = identity_uri_transform(identity_admin_endpoint)

db_user = node['openstack']['db']['network']['username']
db_pass = get_password 'db', 'neutron'
sql_connection = db_uri('network', db_user, db_pass)
if node['openstack']['endpoints']['db']['enabled_slave']
  slave_connection = db_uri('network', db_user, db_pass, true)
end

network_api_bind = endpoint 'network-api-bind'
service_pass = get_password 'service', 'openstack-network'

platform_options['neutron_client_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
end

# all recipes include default.rb, and some servers
# may just be running a subset of agents (like l3_agent)
# and not the api server components, so we add logic to
# check whether current node is network node or not. If
# not, we won't notify this service to restart.
service 'neutron-server' do
  service_name platform_options['neutron_server_service']
  supports status: true, restart: true

  action :nothing
end

# Nova interactions
nova_endpoint = internal_endpoint 'compute-api'
# TODO(MRV): Need to allow for this in common.
# Neutron will append the admin_tenant_id for these nova interaction calls,
# remove the tenant_id so we don't end up with two of them on the url.
# Need to also allow for getting at nova endpoint version.
# https://github.com/openstack/neutron/blob/master/neutron/common/config.py#L94
# https://github.com/openstack/neutron/blob/master/neutron/notifiers/nova.py#L44
nova_version = node['openstack']['network']['nova']['url_version']
nova_endpoint = uri_from_hash('scheme' => nova_endpoint.scheme.to_s, 'host' => nova_endpoint.host.to_s, 'port' => nova_endpoint.port.to_s, 'path' => nova_version)
nova_admin_pass = get_password 'service', 'openstack-compute'

# The auth_url in nova section follows auth_plugin
nova_auth_url = nil
case node['openstack']['network']['nova']['auth_plugin'].downcase
when 'password'
  nova_auth_url = identity_uri
when 'v2password'
  nova_auth_url = auth_uri_transform(identity_admin_endpoint.to_s, 'v2.0')
when 'v3password'
  nova_auth_url = auth_uri_transform(identity_admin_endpoint.to_s, 'v3.0')
end

if node['openstack']['network']['l3']['router_distributed'] == 'auto'
  if node['openstack']['network']['interface_driver'].split('.').last != 'OVSInterfaceDriver'
    node.set['openstack']['network']['l3']['router_distributed'] = 'false'
    Chef::Log.warn('OVSInterfaceDirver is not used as interface_driver, DVR is not supported without OVS')
  end
end

router_distributed = 'False'
if ['auto', 'true', true].include?(node['openstack']['network']['l3']['router_distributed'])
  if recipe_included? 'openstack-network::server'
    router_distributed = 'True'
  else
    router_distributed = 'False'
  end
end
template '/etc/neutron/neutron.conf' do
  source 'neutron.conf.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00640
  variables(
    bind_address: network_api_bind.host,
    bind_port: network_api_bind.port,
    rabbit_hosts: rabbit_hosts,
    mq_service_type: mq_service_type,
    mq_password: mq_password,
    core_plugin: core_plugin,
    auth_uri: auth_uri,
    identity_uri: identity_uri,
    identity_admin_endpoint: identity_admin_endpoint,
    service_pass: service_pass,
    sql_connection: sql_connection,
    slave_connection: slave_connection,
    nova_endpoint: nova_endpoint,
    nova_admin_pass: nova_admin_pass,
    nova_auth_url: nova_auth_url,
    router_distributed: router_distributed
  )

  notifies :restart, 'service[neutron-server]', :delayed if role_match
end

directory "/etc/neutron/plugins/#{main_plugin}" do
  recursive true
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode 00700
end

# For several plugins, the plugin configuration
# is required by both the neutron-server and
# ancillary services that may be on different
# physical servers like the l3 agent, so we assume
# the plugin configuration is a "common" file

template_file = nil

# Common template values (between ML2 and Openvswitch)
tunnel_types = node['openstack']['network']['openvswitch']['tunnel_types']
l2_population = 'False'
enable_distributed_routing = 'False'
if ['auto', 'true', true].include?(node['openstack']['network']['l3']['router_distributed'])
  tunnel_types = 'gre, vxlan'
  l2_population = 'True'
  enable_distributed_routing = 'True'
end

case main_plugin
when 'bigswitch'

  template_file = '/etc/neutron/plugins/bigswitch/restproxy.ini'

  template template_file do
    source 'plugins/bigswitch/restproxy.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'brocade'

  template_file = '/etc/neutron/plugins/brocade/brocade.ini'

  template template_file do
    source 'plugins/brocade/brocade.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'cisco'

  template_file = '/etc/neutron/plugins/cisco/cisco_plugins.ini'

  template template_file do
    source 'plugins/cisco/cisco_plugins.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'hyperv'

  template_file = '/etc/neutron/plugins/hyperv/hyperv_neutron_plugin.ini.erb'

  template template_file do
    source 'plugins/hyperv/hyperv_neutron_plugin.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'linuxbridge'

  linuxbridge_endpoint = endpoint 'network-linuxbridge'
  template_file = '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini'

  template template_file do
    source 'plugins/linuxbridge/linuxbridge_conf.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    variables(
      local_ip: linuxbridge_endpoint.host
    )

    notifies :restart, 'service[neutron-server]', :delayed if role_match
    if node.run_list.expand(node.chef_environment).recipes.include?('openstack-network::linuxbridge')
      notifies :restart, 'service[neutron-plugin-linuxbridge-agent]', :delayed
    end
  end

when 'metaplugin'

  template_file = '/etc/neutron/plugins/metaplugin/metaplugin.ini'

  template template_file do
    source 'plugins/metaplugin/metaplugin.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'midonet'

  template_file = '/etc/neutron/plugins/midonet/midonet.ini'

  template template_file do
    source 'plugins/midonet/midonet.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'ml2'

  openvswitch_endpoint = endpoint 'network-openvswitch'
  template_file = '/etc/neutron/plugins/ml2/ml2_conf.ini'
  mechanism_drivers = node['openstack']['network']['ml2']['mechanism_drivers']
  if node['openstack']['network']['l3']['router_distributed'] == 'auto'
    mechanism_drivers = 'openvswitch,l2population'
  end

  template template_file do
    source 'plugins/ml2/ml2_conf.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    variables(
      mechanism_drivers: mechanism_drivers,
      local_ip: openvswitch_endpoint.host,
      tunnel_types: tunnel_types,
      l2_population: l2_population,
      enable_distributed_routing: enable_distributed_routing
    )

    notifies :restart, 'service[neutron-server]', :delayed if role_match
    if node['recipes'].include?('openstack-network::openvswitch')
      notifies :restart, 'service[neutron-plugin-openvswitch-agent]', :delayed
    end
  end

when 'nec'

  template_file = '/etc/neutron/plugins/nec/nec.ini'

  template template_file do
    source 'plugins/nec/nec.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'nicira'

  template_file = '/etc/neutron/plugins/nicira/nvp.ini'

  template template_file do
    source 'plugins/nicira/nvp.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'openvswitch'

  openvswitch_endpoint = endpoint 'network-openvswitch'
  template_file = '/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini'

  template template_file do
    source 'plugins/openvswitch/ovs_neutron_plugin.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    variables(
      local_ip: openvswitch_endpoint.host,
      tunnel_types: tunnel_types,
      l2_population: l2_population,
      enable_distributed_routing: enable_distributed_routing
    )
    notifies :restart, 'service[neutron-server]', :delayed if role_match
    if node.run_list.expand(node.chef_environment).recipes.include?('openstack-network::openvswitch')
      notifies :restart, 'service[neutron-plugin-openvswitch-agent]', :delayed
    end
  end

when 'plumgrid'

  template_file = '/etc/neutron/plugins/plumgrid/plumgrid.ini'

  template template_file do
    source 'plugins/plumgrid/plumgrid.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

when 'ryu'

  template_file = '/etc/neutron/plugins/ryu/ryu.ini'

  template template_file do
    source 'plugins/ryu/ryu.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :restart, 'service[neutron-server]', :delayed if role_match
  end

else
  Chef::Log.fatal("Main plugin #{main_plugin}is not supported")
end

link '/etc/neutron/plugin.ini' do
  to template_file
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  action :create
  only_if { platform_family? %w(fedora rhel) }
end

node.set['openstack']['network']['plugin_config_file'] = template_file

template '/etc/default/neutron-server' do
  source 'neutron-server.erb'
  owner 'root'
  group 'root'
  mode 00644
  variables(
    plugin_config: template_file
  )
  only_if do
    node.run_list.expand(node.chef_environment).recipes.include?('openstack-network::server')
    platform_family?('debian')
  end
end
