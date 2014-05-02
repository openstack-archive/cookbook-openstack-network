# Encoding: utf-8
#
# Cookbook Name:: openstack-network
# Recipe:: dhcp_agent
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

['quantum', 'neutron'].include?(node['openstack']['compute']['network']['service_type']) || return

include_recipe 'openstack-network::common'

platform_options = node['openstack']['network']['platform']
core_plugin = node['openstack']['network']['core_plugin']
main_plugin = node['openstack']['network']['core_plugin_map'][core_plugin.split('.').last.downcase]

platform_options['neutron_dhcp_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

service 'neutron-dhcp-agent' do
  service_name platform_options['neutron_dhcp_agent_service']
  supports status: true, restart: true

  action :enable
  subscribes :restart, 'template[/etc/neutron/neutron.conf]'
end

# Some plugins have DHCP functionality, so we install the plugin
# Python package and include the plugin-specific recipe here...
package platform_options['neutron_plugin_package'].gsub('%plugin%', main_plugin) do
  options platform_options['package_overrides']
  action :upgrade
  # plugins are installed by the main openstack-neutron package on SUSE
  not_if { platform_family? 'suse' }
end

template '/etc/neutron/dnsmasq.conf' do
  source 'dnsmasq.conf.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode   00644
  notifies :restart, 'service[neutron-dhcp-agent]', :delayed
end

template '/etc/neutron/dhcp_agent.ini' do
  source 'dhcp_agent.ini.erb'
  owner node['openstack']['network']['platform']['user']
  group node['openstack']['network']['platform']['group']
  mode   00644
  notifies :restart, 'service[neutron-dhcp-agent]', :immediately
end

# Deal with ubuntu precise dnsmasq 2.59 version by custom
# compiling a more recent version of dnsmasq
#
# See:
# https://lists.launchpad.net/openstack/msg11696.html
# https://bugs.launchpad.net/ubuntu/+source/dnsmasq/+bug/1013529
# https://bugs.launchpad.net/ubuntu/+source/dnsmasq/+bug/1103357
# http://www.thekelleys.org.uk/dnsmasq/CHANGELOG (SO_BINDTODEVICE)
#
# Would prefer a PPA or backport but there are none and upstream
# has no plans to fix
if node['lsb'] && node['lsb']['codename'] == 'precise' && node['openstack']['network']['dhcp']['dnsmasq_compile'] == true
  platform_options['neutron_dhcp_build_packages'].each do |pkg|
    package pkg do
      action :upgrade
    end
  end

  dhcp_options = node['openstack']['network']['dhcp']

  src_filename = dhcp_options['dnsmasq_filename']
  src_filepath = "#{Chef::Config['file_cache_path']}/#{src_filename}"
  extract_path = "#{Chef::Config['file_cache_path']}/#{dhcp_options['dnsmasq_checksum']}"

  remote_file src_filepath do
    source dhcp_options['dnsmasq_url']
    checksum dhcp_options['dnsmasq_checksum']
    owner 'root'
    group 'root'
    mode 00644
  end

  bash 'extract_package' do
    cwd ::File.dirname(src_filepath)
    code <<-EOH
      mkdir -p #{extract_path}
      tar xzf #{src_filename} -C #{extract_path}
      mv #{extract_path}/*/* #{extract_path}/
      cd #{extract_path}/
      echo '2.65' > VERSION
      debian/rules binary
      EOH
    not_if { ::File.exists?(extract_path) }
    notifies :install, 'dpkg_package[dnsmasq-utils]', :immediately
    notifies :install, 'dpkg_package[dnsmasq-base]', :immediately
    notifies :install, 'dpkg_package[dnsmasq]', :immediately
  end

  # wait for dnsmasq to start properly. Don't wait forever
  ruby_block 'wait for dnsmasq' do
    block do
      count = 5
      counter = 0
      while counter < count
        run = Mixlib::ShellOut.new('dig +time=5 @localhost | grep -q root-server[s]').run_command
        break unless run.exitstatus > 0
        counter += 1
        Chef::Log.fatal('dnsmasq never became ready') if counter == count
        sleep 1
      end
    end
    action :nothing
  end

  dpkg_package 'dnsmasq-utils' do
    source "#{extract_path}/../dnsmasq-utils_#{dhcp_options['dnsmasq_dpkgversion']}_#{dhcp_options['dnsmasq_architecture']}.deb"
    action :nothing
  end
  dpkg_package 'dnsmasq-base' do
    source "#{extract_path}/../dnsmasq-base_#{dhcp_options['dnsmasq_dpkgversion']}_#{dhcp_options['dnsmasq_architecture']}.deb"
    action :nothing
  end
  dpkg_package 'dnsmasq' do
    source "#{extract_path}/../dnsmasq_#{dhcp_options['dnsmasq_dpkgversion']}_all.deb"
    action :nothing
    notifies :create, 'ruby_block[wait for dnsmasq]', :immediately
  end

end
