# encoding: UTF-8
#
# Cookbook Name:: openstack-network
# Attributes:: default
#
# Copyright 2013, AT&T
# Copyright 2014, IBM Corp.
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

# Set the endpoints for the network service to allow all other cookbooks to
# access and use them
%w(public internal admin).each do |ep_type|
  # openstack identity service endpoints (used by users and services)
  default['openstack']['endpoints'][ep_type]['network']['host'] = '127.0.0.1'
  default['openstack']['endpoints'][ep_type]['network']['scheme'] = 'http'
  default['openstack']['endpoints'][ep_type]['network']['path'] = ''
  default['openstack']['endpoints'][ep_type]['network']['port'] = 9696
  # web-service (e.g. apache) listen address (can be different from openstack
  # network endpoints)
end
default['openstack']['bind_service']['all']['network']['host'] = '127.0.0.1'
default['openstack']['bind_service']['all']['network']['port'] = 9696

# trigger the usage of syslog (will include the proper recipe to create a log
# config)
default['openstack']['network']['syslog']['use'] = false
# Name of the plugin to load
default['openstack']['network']['nova']['auth_plugin'] = 'v2password'
# Name of the plugin to load
default['openstack']['network']['identity-api']['auth']['version'] = 'v2.0'
# Set dbsync command timeout value
default['openstack']['network']['dbsync_timeout'] = 3600
# Specify policy.json remote filwe to import
default['openstack']['network']['policyfile_url'] = nil
# Gets set in the Network Endpoint when registering with Keystone
default['openstack']['network']['region'] = node['openstack']['region']
default['openstack']['network']['service_role'] = 'admin'
default['openstack']['network']['service_name'] = 'neutron'
default['openstack']['network']['service_type'] = 'network'
default['openstack']['network']['description'] = 'OpenStack Networking service'
default['openstack']['network']['rabbit_server_chef_role'] = 'rabbitmq-server'
# Keystone PKI signing directory.
default['openstack']['network']['api']['auth']['cache_dir'] = '/var/cache/neutron/api'
# The bridging interface driver.
# This is used by the L3, DHCP and LBaaS agents.
# Options are:
#
#   - neutron.agent.linux.interface.OVSInterfaceDriver
#   - neutron.agent.linux.interface.BridgeInterfaceDriver
#
default['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
# The agent can use other DHCP drivers.  Dnsmasq is the simplest and requires
# no additional setup of the DHCP server.
default['openstack']['network']['dhcp_driver'] = 'neutron.agent.linux.dhcp.Dnsmasq'
# Version for connection to nova
# TODO: (MRV) Need to allow for this in Common.
default['openstack']['network']['nova']['url_version'] = '/v2'

#
# ============================= rootwrap Configuration ===================
# use neutron root wrap
default['openstack']['network']['use_rootwrap'] = true
# rootwrap.conf
default['openstack']['network']['rootwrap']['conf'].tap do |conf|
  conf['DEFAULT']['filters_path'] = '/etc/neutron/rootwrap.d,/usr/share/neutron/rootwrap'
  conf['DEFAULT']['exec_dirs'] = '/sbin,/usr/sbin,/bin,/usr/bin'
  conf['DEFAULT']['use_syslog'] = false
  conf['DEFAULT']['syslog_log_facility'] = 'syslog'
  conf['DEFAULT']['syslog_log_level'] = 'ERROR'
end

# ============================= dnsmasq Configuration ===================
# TODO: (jklare) this should be refactored and probably pull in the some dnsmasq
# cookbook to do the proper configuration
# Override the default mtu setting given to virtual machines
# to 1454 to allow for tunnel and other encapsulation overhead.  You
# can adjust this from 1454 to 1500 if you do not want any lowering
# of the default guest MTU.
default['openstack']['network']['dnsmasq']['dhcp-option'] = '26,1454'
# the version of dnsmasq for centos 6.5 is two revs behind where the dhcp-agent needs
# to run properly. This is a version that allows and starts the dhcp-agent correctly.
default['openstack']['network']['dnsmasq']['rpm_version'] = '2.65-1.el6.rfx.x86_64'
default['openstack']['network']['dnsmasq']['rpm_source'] = "http://pkgs.repoforge.org/dnsmasq/dnsmasq-#{node['openstack']['network']['dnsmasq']['rpm_version']}.rpm"
# Upstream resolver to use
# This will be used by dnsmasq to resolve recursively
# but will not be used if the tenant specifies a dns
# server in their subnet
#
# Defaults are spread out across multiple, presumably
# reliable, upstream providers
#
# 8.8.8.8 is Google
# 209.244.0.3 is Level3
#
# May be a comma separated list of servers
default['openstack']['network']['dnsmasq']['upstream_dns_servers'] = %w(8.8.8.8 209.244.0.3)

# ============================= DHCP Agent Configuration ===================
default['openstack']['network_dhcp']['config_file'] = '/etc/neutron/dhcp_agent.ini'
default['openstack']['network_dhcp']['conf'].tap do |conf|
  conf['DEFAULT']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
  conf['DEFAULT']['dnsmasq_config_file '] = '/etc/neutron/dnsmasq.conf'
end

# ============================= L3 Agent Configuration =====================
default['openstack']['network_l3']['external_network_bridge_interface'] = 'eth1'

# Customize the l3 config file path
default['openstack']['network_l3']['config_file'] = '/etc/neutron/l3_agent.ini'
default['openstack']['network_l3']['conf'].tap do |conf|
  conf['DEFAULT']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
  # Name of bridge used for external network traffic. This should be set to
  # empty value for the linux bridge. When external_network_bridge is empty or nil,
  # creation of external bridge will be skipped in the recipe.
  # Interface to use for external bridge.
  conf['DEFAULT']['external_network_bridge'] = 'br-ex'
end

# ============================= Metadata Agent Configuration ===============

default['openstack']['network_metadata']['config_file'] = '/etc/neutron/metadata_agent.ini'
# The name of the secret databag containing the metadata secret
default['openstack']['network_metadata']['secret_name'] = 'neutron_metadata_secret'
node.default['openstack']['network_metadata']['conf'] = {}

# ============================= VPN Agent Configuration ====================
# vpn_device_driver_packages in platform-specific settings is used to get driver dependencies installed, default is openswan
# vpn_device_driver_services in platform-specific settings is used to enable services required by vpn drivers, default is ipsec
# Set to true to enable vpnaas
default['openstack']['network_vpnaas']['enabled'] = false
# Custom the vpnaas config file path
default['openstack']['network_vpnaas']['config_file'] = '/etc/neutron/vpn_agent.ini'
default['openstack']['network_vpnaas']['conf'].tap do |conf|
  # VPN device drivers which vpn agent will use
  conf['DEFAULT']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
  conf['vpnagent']['vpn_device_driver'] = 'neutron_vpnaas.services.vpn.device_drivers.ipsec.OpenSwanDriver'
  # Status check interval for ipsec vpn
  conf['ipsec']['ipsec_status_check_interval'] = 60
  # default_config_area settings is used to set the area where default StrongSwan configuration files are located
  case platform_family
  when 'fedora', 'rhel'
    conf['strongswan']['default_config_area'] = '/usr/share/strongswan/templates/config/strongswan.d'
  when 'debian'
    conf['strongswan']['default_config_area'] = '/etc/strongswan.d'
  end
end

# ============================= LBaaS Agent Configuration ==================
# Set to true to enable lbaas
default['openstack']['network_lbaas']['enabled'] = false
# Custom the lbaas config file path
default['openstack']['network_lbaas']['config_file'] = '/etc/neutron/lbaas_agent.ini'
default['openstack']['network_lbaas']['conf'].tap do |conf|
  conf['DEFAULT']['periodic_interval'] = 10
  conf['DEFAULT']['ovs_use_veth'] = false
  conf['DEFAULT']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
  conf['DEFAULT']['device_driver'] = 'neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver'
  case platform_family
  when 'fedora', 'rhel'
    conf['haproxy']['user_group'] = 'nobody'
  when 'debian'
    conf['haproxy']['user_group'] = 'nogroup'
  end
end

# ============================= FWaaS Configuration ==================
# TODO(jklare) : check why the package is installed and if the configuration
# works at all (if so, this needs refactoring parallel to the lbaas and vpnaas
# recipes and attributes)
# Set to True to enable firewall service
default['openstack']['network_fwaas']['enabled'] = false
# Firewall service driver with linux iptables
# default['openstack']['network']['fwaas']['driver'] = 'neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver'
# Custom the fwaas config file path
# default['openstack']['network']['fwaas']['config_file'] = '/etc/neutron/fwaas_driver.ini'
# ============================= platform-specific settings ===========
default['openstack']['network']['platform'].tap do |platform|
  platform['user'] = 'neutron'
  platform['group'] = 'neutron'
  platform['vpn_device_driver_packages'] =
    %w(openswan)
  platform['neutron_dhcp_agent_service'] =
    'neutron-dhcp-agent'
  platform['neutron_l3_agent_service'] =
    'neutron-l3-agent'
  platform['neutron_vpn_agent_service'] =
    'neutron-vpn-agent'
  platform['vpn_device_driver_services'] =
    %w(ipsec)
  platform['neutron_lb_agent_service'] =
    'neutron-lbaas-agent'
  platform['neutron_metadata_agent_service'] =
    'neutron-metadata-agent'
  platform['neutron_server_service'] =
    'neutron-server'
  case platform_family
  when 'fedora', 'rhel' # :pragma-foodcritic: ~FC024 - won't fix this
    platform['neutron_packages'] =
      %w(openstack-neutron openstack-neutron-ml2 iproute)
    platform['neutron_client_packages'] =
      %w(python-neutronclient)
    platform['neutron_dhcp_packages'] =
      %w(openstack-neutron iproute)
    platform['neutron_l3_packages'] =
      %w(openstack-neutron iproute radvd keepalived)
    platform['neutron_plugin_package'] =
      'neutron-plugin-ml2'
    # openstack-neutron-fwaas
    platform['neutron_vpnaas_packages'] =
      %w(openstack-neutron-vpnaas iproute)
    platform['neutron_lbaas_packages'] =
      %w(openstack-neutron-lbaas haproxy iproute)
    platform['neutron_openvswitch_packages'] =
      %w(openvswitch)
    platform['neutron_openvswitch_agent_packages'] =
      %w(openstack-neutron-openvswitch iproute)
    platform['neutron_linuxbridge_agent_packages'] =
      %w(openstack-neutron-linuxbridge iproute)
    platform['neutron_linuxbridge_agent_service'] =
      %w(neutron-plugin-linuxbridge-agent)
    platform['neutron_metadata_agent_packages'] =
      %w()
    platform['neutron_server_packages'] =
      %w()
    platform['neutron_openvswitch_service'] =
      'openvswitch'
    platform['neutron_openvswitch_agent_service'] =
      'neutron-openvswitch-agent'
    platform['package_overrides'] =
      ''
  when 'debian'
    platform['neutron_packages'] =
      %w(neutron-common python-pyparsing python-cliff)
    platform['neutron_client_packages'] =
      %w(python-neutronclient python-pyparsing)
    platform['neutron_dhcp_packages'] =
      %w(neutron-dhcp-agent)
    platform['neutron_l3_packages'] =
      %w(neutron-l3-agent radvd keepalived)
    # python-neutron-fwaas
    platform['neutron_vpnaas_packages'] =
      %w(python-neutron-vpnaas neutron-vpn-agent)
    platform['neutron_lbaas_packages'] =
      %w(python-neutron-lbaas neutron-lbaas-agent haproxy)
    platform['neutron_openvswitch_packages'] =
      %w(openvswitch-switch openvswitch-datapath-dkms bridge-utils)
    platform['neutron_openvswitch_build_packages'] =
      %w(
        build-essential pkg-config fakeroot
        libssl-dev openssl debhelper
        autoconf dkms python-all
        python-qt4 python-zopeinterface
        python-twisted-conch
      )
    platform['neutron_openvswitch_agent_packages'] =
      %w(neutron-plugin-openvswitch neutron-plugin-openvswitch-agent)
    platform['neutron_linuxbridge_agent_packages'] =
      %w(neutron-plugin-linuxbridge neutron-plugin-linuxbridge-agent)
    platform['neutron_linuxbridge_agent_service'] =
      'neutron-plugin-linuxbridge-agent'
    platform['neutron_metadata_agent_packages'] =
      %w(neutron-metadata-agent)
    platform['neutron_server_packages'] =
      %w(neutron-server)
    platform['neutron_openvswitch_service'] =
      'openvswitch-switch'
    platform['neutron_openvswitch_agent_service'] =
      'neutron-plugin-openvswitch-agent'
    platform['package_overrides'] =
      "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef'"
  end
end
