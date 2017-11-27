# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: identity_registration
#
# Copyright 2013, AT&T
# Copyright 2013, SUSE Linux GmbH
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

require 'uri'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

identity_admin_endpoint = admin_endpoint 'identity'

auth_url = ::URI.decode identity_admin_endpoint.to_s

interfaces = {
  public: { url: public_endpoint('network') },
  internal: { url: internal_endpoint('network') },
  admin: { url: admin_endpoint('network') },
}

service_pass = get_password 'service', 'openstack-network'
service_tenant_name =
  node['openstack']['network']['conf']['keystone_authtoken']['project_name']

service_user =
  node['openstack']['network']['conf']['keystone_authtoken']['username']
service_role = node['openstack']['network']['service_role']
service_domain_name = node['openstack']['network']['conf']['keystone_authtoken']['user_domain_name']
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', node['openstack']['identity']['admin_user']
admin_project = node['openstack']['identity']['admin_project']
admin_domain = node['openstack']['identity']['admin_domain_name']
region = node['openstack']['region']

# Do not configure a service/endpoint in keystone for heat-api-cloudwatch(Bug #1167927),
# See discussions on https://bugs.launchpad.net/heat/+bug/1167927

connection_params = {
  openstack_auth_url:     "#{auth_url}/auth/tokens",
  openstack_username:     admin_user,
  openstack_api_key:      admin_pass,
  openstack_project_name: admin_project,
  openstack_domain_name:    admin_domain,
}

# Register Network Service
openstack_service 'neutron' do
  type 'network'
  connection_params connection_params
end

# Register Network Public-Endpoint
interfaces.each do |interface, res|
  # Register network Endpoints
  openstack_endpoint 'network' do
    service_name 'neutron'
    interface interface.to_s
    url res[:url].to_s
    region region
    connection_params connection_params
  end
end
# Register Service Tenant
openstack_project service_tenant_name do
  connection_params connection_params
end

# Register Service User
openstack_user service_user do
  role_name service_role
  project_name service_tenant_name
  domain_name service_domain_name
  password service_pass
  connection_params connection_params
  action [:create, :grant_role]
end
