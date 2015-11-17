# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: ml2_core_plugin
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

case node['platform_family']
when 'fedora', 'rhel'
  node.default['openstack']['network']['plugins']['ml2']['path'] = '/etc/neutron'
  node.default['openstack']['network']['plugins']['ml2']['filename'] = 'plugin.ini'
when 'debian'
  node.default['openstack']['network']['plugins']['ml2']['path'] = '/etc/neutron/plugins/ml2'
  node.default['openstack']['network']['plugins']['ml2']['filename'] = 'ml2_conf.ini'
end

# Per default the ml2 conf will be empty, since there is no need to add
# configuration without a mechanism_driver defined. The proper mechanism_drivers
# configuration will be included automatically when selecting a fitting
# ml2_plugin like ml2_openvswitch or ml2_linuxbridge
node.default['openstack']['network']['plugins']['ml2']['conf'] = {}

core_plugin = node['openstack']['network']['conf']['DEFAULT']['core_plugin']
node.default['openstack']['network']['core_plugin_config_file'] =
  File.join(
    node['openstack']['network']['plugins'][core_plugin]['path'],
    node['openstack']['network']['plugins'][core_plugin]['filename']
  )
