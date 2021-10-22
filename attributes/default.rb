#
# Cookbook:: openstack-network
# Attributes:: default
#
# Copyright:: 2013-2021, AT&T
# Copyright:: 2014-2021, IBM Corp.
# Copyright:: 2016-2021, Oregon State University
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
%w(public internal).each do |ep_type|
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
default['openstack']['network']['identity-api']['auth']['version'] = 'v3'
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
# The bridging interface driver.
# This is used by the L3 and DHCP agents.
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
# Upstream resolver to use
# This will be used by dnsmasq to resolve recursively
# but will not be used if the tenant specifies a dns
# server in their subnet
#
# Defaults are spread out across multiple, presumably
# reliable, upstream providers. Deployers should replace these with their local
# resolvers when possible.
#
# 8.8.8.8 is Google
# 208.67.222.222 is OpenDNS
#
# May be a comma separated list of servers
default['openstack']['network']['dnsmasq']['upstream_dns_servers'] = %w(8.8.8.8 208.67.222.222)

# List of domains and corresponding IP addresses to override upstream DNS
# servers. The format expected by dnsmasq is /<domain>/<address>,
# e.g. "/double-click.net/127.0.0.1" or "/localhost/::1".
default['openstack']['network']['dnsmasq']['override_dns_address'] = %w()

# ============================= DHCP Agent Configuration ===================
default['openstack']['network_dhcp']['config_file'] = '/etc/neutron/dhcp_agent.ini'
default['openstack']['network_dhcp']['conf'].tap do |conf|
  conf['DEFAULT']['interface_driver'] = 'openvswitch'
  conf['DEFAULT']['dnsmasq_config_file '] = '/etc/neutron/dnsmasq.conf'
end

# ============================= L3 Agent Configuration =====================
default['openstack']['network_l3']['external_network_bridge_interface'] = 'enp0s8'

# Customize the l3 config file path
default['openstack']['network_l3']['config_file'] = '/etc/neutron/l3_agent.ini'
default['openstack']['network_l3']['conf'].tap do |conf|
  conf['DEFAULT']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
end

# ============================= Metadata Agent Configuration ===============

default['openstack']['network_metadata']['config_file'] = '/etc/neutron/metadata_agent.ini'
# The name of the secret databag containing the metadata secret
default['openstack']['network_metadata']['secret_name'] = 'neutron_metadata_secret'
node.default['openstack']['network_metadata']['conf'] = {}

# ============================= Metering Agent Configuration ===============

default['openstack']['network_metering']['config_file'] = '/etc/neutron/metering_agent.ini'
default['openstack']['network_metering']['conf'].tap do |conf|
  conf['DEFAULT']['interface_driver'] = 'neutron.agent.linux.interface.OVSInterfaceDriver'
  conf['DEFAULT']['driver'] = 'neutron.services.metering.drivers.iptables.iptables_driver.IptablesMeteringDriver'
end

# ============================= platform-specific settings ===========
default['openstack']['network']['platform'].tap do |platform|
  platform['user'] = 'neutron'
  platform['group'] = 'neutron'
  platform['neutron_dhcp_agent_service'] = 'neutron-dhcp-agent'
  platform['neutron_l3_agent_service'] = 'neutron-l3-agent'
  platform['neutron_metadata_agent_service'] = 'neutron-metadata-agent'
  platform['neutron_metering_agent_service'] = 'neutron-metering-agent'
  platform['neutron_server_service'] = 'neutron-server'
  platform['neutron_rpc_server_service'] = 'neutron-rpc-server'
  case node['platform_family']
  when 'rhel'
    platform['neutron_packages'] =
      %w(
        ebtables
        iproute
        openstack-neutron
        openstack-neutron-ml2
      )
    platform['neutron_dhcp_packages'] = %w(openstack-neutron iproute)
    platform['neutron_l3_packages'] =
      %w(
        iproute
        keepalived
        openstack-neutron
        radvd
      )
    platform['neutron_plugin_package'] = 'neutron-plugin-ml2'
    platform['neutron_openvswitch_packages'] = %w(openvswitch)
    platform['neutron_openvswitch_agent_packages'] = %w(openstack-neutron-openvswitch iproute)
    platform['neutron_linuxbridge_agent_packages'] = %w(openstack-neutron-linuxbridge iproute)
    platform['neutron_linuxbridge_agent_service'] = 'neutron-linuxbridge-agent'
    platform['neutron_metadata_agent_packages'] = []
    platform['neutron_metering_agent_packages'] = %w(openstack-neutron-metering-agent)
    platform['neutron_server_packages'] = []
    platform['neutron_openvswitch_service'] = 'openvswitch'
    platform['neutron_openvswitch_agent_service'] = 'neutron-openvswitch-agent'
    platform['package_overrides'] = ''
  when 'debian'
    platform['neutron_packages'] = %w(neutron-common python3-neutron)
    platform['neutron_dhcp_packages'] = %w(neutron-dhcp-agent)
    platform['neutron_l3_packages'] =
      %w(
        keepalived
        neutron-l3-agent
        radvd
      )
    platform['neutron_openvswitch_packages'] = %w(openvswitch-switch bridge-utils)
    platform['neutron_openvswitch_build_packages'] =
      %w(
        autoconf
        build-essential
        debhelper
        dkms
        fakeroot
        libssl-dev
        openssl
        pkg-config
        python-all
        python-qt4
        python-twisted-conch
        python-zopeinterface
      )
    platform['neutron_openvswitch_agent_packages'] = %w(neutron-openvswitch-agent)
    platform['neutron_linuxbridge_agent_packages'] = %w(neutron-linuxbridge-agent)
    platform['neutron_linuxbridge_agent_service'] = 'neutron-linuxbridge-agent'
    platform['neutron_metadata_agent_packages'] = %w(neutron-metadata-agent)
    platform['neutron_metering_agent_packages'] = %w(neutron-metering-agent)
    platform['neutron_server_packages'] = %w(neutron-server)
    platform['neutron_openvswitch_service'] = 'openvswitch-switch'
    platform['neutron_openvswitch_agent_service'] = 'neutron-openvswitch-agent'
    platform['package_overrides'] = ''
  end
end
