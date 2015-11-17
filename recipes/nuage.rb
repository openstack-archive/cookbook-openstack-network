# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: nuage
#
# Copyright 2015, AT&T
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
  include ::Utils
end

platform_options = node['openstack']['network']['platform']

if recipe_included? 'openstack-network::server'
  # INSTALL PACKAGES
  platform_options['neutron_server_nuage_packages'].each do |pkg|
    package pkg do
      action :upgrade
      options platform_options['package_overrides']
    end
  end
end

include_recipe 'openstack-network'

if recipe_included? 'openstack-compute::compute'
  # SELINUX PERMISSIVE
  include_recipe 'selinux::permissive'

  # INSTALL PACKAGES
  platform_options['compute_nuage_packages'].each do |pkg|
    package pkg do
      action :upgrade
      options platform_options['package_overrides']
    end
  end

  # VRS CONFIGURATION /etc/default/openvswitch
  ruby_block 'insert_controllers' do
    block do
      file = Chef::Util::FileEdit.new('/etc/default/openvswitch')

      active_controller_ip = node['openstack']['network']['nuage']['active_controller']
      active_controller = "ACTIVE_CONTROLLER=#{active_controller_ip}"
      file.insert_line_if_no_match('/$ACTIVE_CONTROLLER/', active_controller)

      standby_controller_ip = node['openstack']['network']['nuage']['standby_controller']
      unless standby_controller_ip.empty?
        standby_controller = "STANDBY_CONTROLLER=#{standby_controller_ip}"
        file.insert_line_if_no_match('/$STANDBY_CONTROLLER/', standby_controller)
      end

      file.write_file
    end
  end

  # NUAGE METADATA CONFIGURATION /etc/default/nuage-metadata-agent
  identity_endpoint = internal_endpoint 'identity-internal'
  service_pass = get_password 'service', 'openstack-network'
  metadata_secret = get_password 'token', node['openstack']['network']['metadata']['secret_name']
  compute_metadata_api = internal_endpoint 'compute-metadata-api'

  template_file = '/etc/default/nuage-metadata-agent'

  template template_file do
    source 'plugins/nuage/nuage-metadata-agent.erb'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    variables(
      identity_endpoint: identity_endpoint,
      metadata_secret: metadata_secret,
      service_pass: service_pass,
      compute_metadata_ip: compute_metadata_api.host,
      compute_metadata_port: compute_metadata_api.port
    )
    mode 00644
  end

  # RESTART openvswitch
  service 'openvswitch' do
    service_name platform_options['neutron_openvswitch_service']
    supports status: true, restart: true
    action :restart
  end
end
