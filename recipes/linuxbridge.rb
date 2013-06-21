#
# Cookbook Name:: openstack-network
# Recipe:: linuxbridge
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

template "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini" do
  source "plugins/linuxbridge/linuxbridge_conf.ini.erb"
  owner node["openstack"]["network"]["user"]
  group node["openstack"]["network"]["group"]
  mode 00644
  variables(
    :sql_connection => sql_connection
  )

  notifies :restart, "service[quantum-server]", :immediately
end
