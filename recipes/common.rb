# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: common
#
# Copyright 2013, AT&T
# Copyright 2013, SUSE Linux GmbH
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

require 'uri'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

# Make Openstack object available in Chef::Resource::RubyBlock
class ::Chef::Resource::RubyBlock
  include ::Openstack
end

platform_options = node['openstack']['network']['platform']

core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

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
platform_options["#{db_type}_python_packages"].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
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
    notifies :restart, 'service[neutron-server]'
  end
end

mq_service_type = node['openstack']['mq']['network']['service_type']

if mq_service_type == 'rabbitmq'
  rabbit_hosts = rabbit_servers if node['openstack']['mq']['network']['rabbit']['ha']
  mq_password = get_password 'user', node['openstack']['mq']['network']['rabbit']['userid']
elsif mq_service_type == 'qpid'
  mq_password = get_password 'user', node['openstack']['mq']['network']['qpid']['username']
end

identity_endpoint = endpoint 'identity-api'
identity_admin_endpoint = endpoint 'identity-admin'
auth_uri = ::URI.decode identity_endpoint.to_s

auth_uri = auth_uri_transform identity_endpoint.to_s, node['openstack']['network']['api']['auth']['version']

db_user = node['openstack']['db']['network']['username']
db_pass = get_password 'db', 'neutron'
sql_connection = db_uri('network', db_user, db_pass)

network_api_bind = endpoint 'network-api-bind'
service_pass = get_password 'service', 'openstack-network'

platform_options['neutron_client_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['package_overrides']
  end
end

# all recipes include common.rb, and some servers
# may just be running a subset of agents (like l3_agent)
# and not the api server components, so we ignore restart
# failures here as there may be no neutron-server process
service 'neutron-server' do
  service_name platform_options['neutron_server_service']
  supports status: true, restart: true
  ignore_failure true

  action :nothing
end

# Nova interactions
nova_endpoint = endpoint 'compute-api'
# TODO(MRV): Need to allow for this in common.
# Neutron will append the admin_tenant_id for these nova interaction calls,
# remove the tenant_id so we don't end up with two of them on the url.
# Need to also allow for getting at nova endpoint version.
# https://github.com/openstack/neutron/blob/master/neutron/common/config.py#L89
# https://github.com/openstack/neutron/blob/master/neutron/notifiers/nova.py#L43
nova_version = node['openstack']['network']['nova']['url_version']
nova_endpoint = uri_from_hash('host' => nova_endpoint.host.to_s, 'port' => nova_endpoint.port.to_s, 'path' => nova_version)
nova_admin_pass = get_password 'service', 'openstack-compute'
ruby_block 'query service tenant uuid' do
  # query keystone for the service tenant uuid
  block do
    begin
      admin_user = node['openstack']['identity']['admin_user']
      admin_tenant = node['openstack']['identity']['admin_tenant_name']
      env = openstack_command_env admin_user, admin_tenant
      tenant_id = identity_uuid 'tenant', 'name', 'service', env
      Chef::Log.error('service tenant UUID for nova_admin_tenant_id not found.') if tenant_id.nil?
      node.set['openstack']['network']['nova']['admin_tenant_id'] = tenant_id
    rescue RuntimeError => e
      Chef::Log.error("Could not query service tenant UUID for nova_admin_tenant_id. Error was #{e.message}")
    end
  end
  action :run
  only_if do
    (node['openstack']['network']['nova']['notify_nova_on_port_status_changes'] == 'True' ||
    node['openstack']['network']['nova']['notify_nova_on_port_data_changes'] == 'True') &&
    node['openstack']['network']['nova']['admin_tenant_id'].nil?
  end
end

template '/etc/neutron/neutron.conf' do
  source 'neutron.conf.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode   00644
  variables(
    bind_address: network_api_bind.host,
    bind_port: network_api_bind.port,
    rabbit_hosts: rabbit_hosts,
    mq_service_type: mq_service_type,
    mq_password: mq_password,
    core_plugin: core_plugin,
    auth_uri: auth_uri,
    identity_admin_endpoint: identity_admin_endpoint,
    service_pass: service_pass,
    sql_connection: sql_connection,
    nova_endpoint: nova_endpoint,
    nova_admin_pass: nova_admin_pass
  )

  notifies :restart, 'service[neutron-server]', :delayed
end

template '/etc/neutron/api-paste.ini' do
  source 'api-paste.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode   00640

  notifies :restart, 'service[neutron-server]', :delayed
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
plugin_file = '/etc/neutron/plugin.ini'

case main_plugin
when 'bigswitch'

  template_file =  '/etc/neutron/plugins/bigswitch/restproxy.ini'

  template template_file do
    source 'plugins/bigswitch/restproxy.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'brocade'

  template_file = '/etc/neutron/plugins/brocade/brocade.ini'

  template template_file do
    source 'plugins/brocade/brocade.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'cisco'

  template_file = '/etc/neutron/plugins/cisco/cisco_plugins.ini'

  template template_file do
    source 'plugins/cisco/cisco_plugins.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'hyperv'

  template_file = '/etc/neutron/plugins/hyperv/hyperv_neutron_plugin.ini.erb'

  template template_file do
    source 'plugins/hyperv/hyperv_neutron_plugin.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
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

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
    if node.run_list.expand(node.chef_environment).recipes.include?('openstack-network::linuxbridge')
      notifies :restart, 'service[neutron-plugin-linuxbridge-agent]', :delayed
    end
  end

when 'midonet'

  template_file = '/etc/neutron/plugins/metaplugin/metaplugin.ini'

  template template_file do
    source 'plugins/metaplugin/metaplugin.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'ml2'

  template_file = '/etc/neutron/plugins/ml2/ml2_conf.ini'

  template template_file do
    source 'plugins/ml2/ml2_conf.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'nec'

  template_file = '/etc/neutron/plugins/nec/nec.ini'

  template template_file do
    source 'plugins/nec/nec.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'nicira'

  template_file = '/etc/neutron/plugins/nicira/nvp.ini'

  template template_file do
    source 'plugins/nicira/nvp.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
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
      local_ip: openvswitch_endpoint.host
    )
    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
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

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

when 'ryu'

  template_file = '/etc/neutron/plugins/ryu/ryu.ini'

  template template_file do
    source 'plugins/ryu/ryu.ini.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644

    notifies :create, "link[#{plugin_file}]", :immediately
    notifies :restart, 'service[neutron-server]', :delayed
  end

else
  Chef::Log.fatal("Main plugin #{main_plugin}is not supported")
end

link plugin_file do
  to template_file
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  action :nothing
  only_if { platform_family? %w{fedora rhel} }
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
    platform_family?(%w{debian})
  end
end
