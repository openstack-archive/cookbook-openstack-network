# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: plugin_config
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

node['openstack']['network']['plugins'].each_value do |plugin|
  next if plugin['path'].nil?
  directory plugin['path'] do
    recursive true
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00700
  end

  template File.join(plugin['path'], plugin['filename']) do
    source 'openstack-service.conf.erb'
    cookbook 'openstack-common'
    owner node['openstack']['network']['platform']['user']
    group node['openstack']['network']['platform']['group']
    mode 00644
    variables(
      service_config: plugin['conf']
    )
  end
end
