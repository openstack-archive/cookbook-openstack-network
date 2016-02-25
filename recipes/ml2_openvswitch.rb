# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: ml2_opensvswitch
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

require 'uri'

# Make Openstack object available in Chef::Recipe
class ::Chef::Recipe
  include ::Openstack
end

include_recipe 'openstack-network::ml2_core_plugin'

node.default['openstack']['network']['plugins']['ml2']['conf']['ml2']['mechanism_drivers'] = 'openvswitch'

node.default['openstack']['network']['plugins']['openvswitch'].tap do |ovs|
  case node['platform_family']
  when 'fedora', 'rhel'
    ovs['path'] =
      '/etc/neutron/plugins/openvswitch'
    ovs['filename'] =
      'ovs_neutron_plugin.ini'
  when 'debian'
    ovs['path'] =
      '/etc/neutron/plugins/ml2'
    ovs['filename'] =
      'openvswitch_agent.ini'
  end
  ovs['conf']['DEFAULT']['integration_bridge'] = 'br-int'
end
