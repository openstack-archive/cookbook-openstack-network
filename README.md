Description
===========

This cookbook installs the **OpenStack Network** service (formerly project-named Quantum, current name is Neutron)
as part of a Chef reference deployment of OpenStack.

More information about the OpenStack Network service is available
[here](http://docs.openstack.org/trunk/openstack-network/admin/content/index.html)

Usage
=====

OpenStack Network's design is modular, with plugins available that handle L2 and
L3 networking for various hardware vendors and standards.

Requirements
============

Chef 11.4.4 or higher required (for Chef environment use)

Cookbooks
---------

The following cookbooks are dependencies:

* openstack-identity
* openstack-common

Recipes
=======

client
------

- Install the network client packages

server
------

- Installs the openstack-network API server

dhcp\_agent
--------

- Installs the DHCP agent

l3\_agent
--------

- Installs the L3 agent and metadata agent

vpn\_agent
--------

- Installs the VPN agent

Identity-registration
---------------------

- Registers the OpenStack Network API endpoint and service user with Keystone

hyperv
------

- Install the drivers for hyperv needed by OpenStack network.
- The networking-hyperv has not been included by linux distributions, it needs been created by users.
- The source code of networking-hyperv maintains in https://github.com/stackforge/networking-hyperv.

Attributes
==========

* `openstack['network']['service_provider']` - Array of service providers (drivers) for advanced services like loadbalancer, VPN, Firewall.
* `openstack['network']['api']['auth']['version']` - Select v2.0 or v3.0. Default v2.0. The auth API version used to interact with identity service.
* `openstack['network']["misc_neutron"]` - Array of strings to be added to neutron.conf
* `openstack['network']['api']['auth']['memcached_servers']` - A list of memcached server(s) for caching
* `openstack['network']['api']['auth']['memcache_security_strategy']` - Whether token data should be authenticated or authenticated and encrypted. Acceptable values are MAC or ENCRYPT.
* `openstack['network']['api']['auth']['memcache_secret_key']` - This string is used for key derivation.
* `openstack['network']['api']['auth']['hash_algorithms']` - Hash algorithms to use for hashing PKI tokens.
* `openstack['network']['api']['auth']['cafile']` - A PEM encoded Certificate Authority to use when verifying HTTPs connections.
* `openstack['network']['api']['auth']['insecure']` - Whether to allow the client to perform insecure SSL (https) requests.
* `openstack['network']['dbsync_timeout']` - Set dbsync command timeout value

TODO
* `openstack["network"]["service_plugins"]` - Array of Python classes to be used as `service_plugins` in neutron.conf (default: []). Set it to ['neutron.plugins.services.agent_loadbalancer.plugin.LoadBalancerPlugin'] to include the load balancer plugin.

Neutron Nova interactions
-------------------------
* `openstack["network"]["nova"]["cafile"]` - CA file for novaclient to verify server certificates
* `openstack["network"]["nova"]["insecure"]` - Boolean to control ignoring SSL errors on the nova url

MQ attributes
-------------
* `openstack["network"]["mq"]["service_type"]` - Select qpid or rabbitmq. default rabbitmq
TODO: move rabbit parameters under openstack["network"]["mq"]
* `openstack["network"]["rabbit"]["username"]` - Username for nova rabbit access
* `openstack["network"]["rabbit"]["vhost"]` - The rabbit vhost to use
* `openstack["network"]["rabbit"]["port"]` - The rabbit port to use
* `openstack["network"]["rabbit"]["host"]` - The rabbit host to use (must set when `openstack["network"]["rabbit"]["ha"]` false).
* `openstack["network"]["rabbit"]["ha"]` - Whether or not to use rabbit ha

* `openstack["network"]["mq"]["qpid"]["host"]` - The qpid host to use
* `openstack["network"]["mq"]["qpid"]["port"]` - The qpid port to use
* `openstack["network"]["mq"]["qpid"]["qpid_hosts"]` - Qpid hosts. TODO. use only when ha is specified.
* `openstack["network"]["mq"]["qpid"]["username"]` - Username for qpid connection
* `openstack["network"]["mq"]["qpid"]["password"]` - Password for qpid connection
* `openstack["network"]["mq"]["qpid"]["sasl_mechanisms"]` - Space separated list of SASL mechanisms to use for auth
* `openstack["network"]["mq"]["qpid"]["reconnect_timeout"]` - The number of seconds to wait before deciding that a reconnect attempt has failed.
* `openstack["network"]["mq"]["qpid"]["reconnect_limit"]` - The limit for the number of times to reconnect before considering the connection to be failed.
* `openstack["network"]["mq"]["qpid"]["reconnect_interval_min"]` - Minimum number of seconds between connection attempts.
* `openstack["network"]["mq"]["qpid"]["reconnect_interval_max"]` - Maximum number of seconds between connection attempts.
* `openstack["network"]["mq"]["qpid"]["reconnect_interval"]` - Equivalent to setting qpid_reconnect_interval_min and qpid_reconnect_interval_max to the same value.
* `openstack["network"]["mq"]["qpid"]["heartbeat"]` - Seconds between heartbeat messages sent to ensure that the connection is still alive.
* `openstack["network"]["mq"]["qpid"]["protocol"]` - Protocol to use. Default tcp.
* `openstack["network"]["mq"]["qpid"]["tcp_nodelay"]` - Disable the Nagle algorithm. default disabled.

Linuxbridge plugin attributes
-----------------------------
* `openstack['openstack']['network']['linuxbridge']['tenant_network_type']` - Type of network to allocate for tenant networks. (default 'local')
* `openstack['openstack']['network']['linuxbridge']['network_vlan_ranges']` - Comma-separated list of <physical_network>[:<vlan_min>:<vlan_max>] tuples enumerating ranges of VLAN IDs
* `openstack['openstack']['network']['linuxbridge']['physical_interface_mappings']` - (ListOpt) Comma-separated list of <physical_network>:<physical_interface> tuples mapping physical network names
* `openstack['openstack']['network']['linuxbridge']['enable_vxlan']` - (BoolOpt) enable VXLAN on the agent. (default false)
* `openstack['openstack']['network']['linuxbridge']['ttl']` - (IntOpt) use specific TTL for vxlan interface protocol packets
* `openstack['openstack']['network']['linuxbridge']['tos']` - (IntOpt) use specific TOS for vxlan interface protocol packets
* `openstack['openstack']['network']['linuxbridge']['vxlan_group']` - (StrOpt) multicast group to use for broadcast emulation. (default '224.0.0.1')
* `openstack['openstack']['network']['linuxbridge']['l2_population']` - (BoolOpt) Flag to enable l2population extension. (default false)
* `openstack['openstack']['network']['linuxbridge']['polling_interval']` - Agent polling interval in seconds. (default 2)
* `openstack['openstack']['network']['linuxbridge']['rpc_support_old_agents']` - (BoolOpt) Enable server RPC compatibility with old (pre-havana). (default false)
* `openstack['openstack']['network']['linuxbridge']['firewall_driver']` - Firewall driver for realizing neutron security group function

Modular Layer 2 Plugin Configuration
------------------------------------
* `openstack['openstack']['network']['ml2']['type_drivers']` - (ListOpt) List of network type driver entrypoints to be loaded from the neutron.ml2.type_drivers namespace.
* `openstack['openstack']['network']['ml2']['tenant_network_types']` - (ListOpt) Ordered list of net work_types to allocate as tenant networks. (default local)
* `openstack['openstack']['network']['ml2']['mechanism_drivers']` - (ListOpt) Ordered list of networ king mechanism driver entrypoints to be loaded from the neutron.ml2.mechanism_drivers namespace.
* `openstack['openstack']['network']['ml2']['flat_networks']` - (ListOpt) List of physical_network names with which flat networks can be created.
* `openstack['openstack']['network']['ml2']['network_vlan_ranges']` - (ListOpt) List of <physical_network>[:<vlan_min>:<vlan_max>] tuples specifying physical_network names usable for VLAN provider and tenant networks
* `openstack['openstack']['network']['ml2']['tunnel_id_ranges']` - (ListOpt) Comma-separated list of <tun_min>:<tun_max> tuples enumerating ranges of GRE tunnel IDs that are available for tenant network allocation
* `openstack['openstack']['network']['ml2']['vni_ranges']` - (ListOpt) Comma-separated list of <vni_min>:<vni_max> tuples enumerating ranges of VXLAN VNI IDs that are available for tenant network allocation.
* `openstack['openstack']['network']['ml2']['vxlan_group']` - (StrOpt) Multicast group for the VXLAN interface.

DHCP Agent Configuration
------------------------
* `openstack['openstack']['network']['dhcp']['dhcp_delete_namespaces']` - (StrOpt) If True, namespaces will be deleted when a dhcp server is disabled.
* `openstack['openstack']['network']['dhcp']['dhcp_agents_per_network']` - (IntOpt) Set the number of dhcp agents for each network. (default 1)

L3 Agent Configuration
----------------------
* `openstack['openstack']['network']['l3']['router_delete_namespaces']` - (StrOpt) If True, namespaces will be deleted when a router is destroyed.
* `openstack['openstack']['network']['l3']['ha']['l3_ha']` - (BoolOpt) If True, virtual router will be created as ha by default. (default False)
* `openstack['openstack']['network']['l3']['ha']['max_l3_agents_per_router']` - (IntOpt)  The maximum number of l3 agents for each ha router. (default 3)
* `openstack['openstack']['network']['l3']['ha']['ha_vrrp_advert_int']` - (IntOpt) The advertisement interval in seconds. (default 2)
* `openstack['openstack']['network']['l3']['router_distributed'] - Both true(bool) and 'true'(str) will set DVR(Distributed Virtual Router) configure enabled. Setting 'auto' will do a simple check then decide whether or not to enable DVR, default is enabled with OVS.
* `openstack['openstack']['network']['l3']['router_delete_namespaces'] - (StrOpt) If True, namespaces will be deleted when a router is destroyed.

VPN Agent Configuration
----------------------
* `openstack['openstack']['network']['enable_vpn'] - (BoolOpt) Used to enable VPN agent, if true, namespaces must be enabled. (default false)
* `openstack['openstack']['network']['vpn']['vpn_device_driver'] - (ListOpt) Comma-separated list of VPN device drivers which VPN agent will use
* `openstack['openstack']['network']['vpn']['ipsec_status_check_interval'] - (IntOpt) Status check interval for ipsec VPN

LBaaS Agent Configuration
----------------------
* `openstack['openstack']['network']['lbaas']['custom_interface_driver']` - Custom plugin to support new interface drivers
* `openstack['openstack']['network']['lbaas']['ovs_use_veth']` - (BoolOpt) Used to enable veth pairs for OVS based plugins

The following attributes are defined in attributes/default.rb of the common cookbook, but are documented here due to their relevance:

* `openstack['endpoints']['network-api-bind']['host']` - The IP address to bind the api service to
* `openstack['endpoints']['network-api-bind']['port']` - The port to bind the api service to
* `openstack['endpoints']['network-api-bind']['bind_interface']` - The interface name to bind the api service to

If the value of the 'bind_interface' attribute is non-nil, then the network service will be bound to the first IP address on that interface.  If the value of the 'bind_interface' attribute is nil, then the network service will be bound to the IP address specified in the host attribute.


Templates
=========
* `neutron.conf.erb` - Config file for OpenStack Network server
* `ml2_conf.ini.erb` - Configuration of Network ML2 Plugins
* `vpn_agent.ini.erb` - Config file for Network VPN agent

Testing
=======

Please refer to the [TESTING.md](TESTING.md) for instructions for testing the cookbook.

Berkshelf
=====

Berks will resolve version requirements and dependencies on first run and
store these in Berksfile.lock. If new cookbooks become available you can run
`berks update` to update the references in Berksfile.lock. Berksfile.lock will
be included in stable branches to provide a known good set of dependencies.
Berksfile.lock will not be included in development branches to encourage
development against the latest cookbooks.

License and Author
==================

|                      |                                                    |
|:---------------------|:---------------------------------------------------|
| **Authors**          |  Alan Meadows (<alan.meadows@gmail.com>)           |
|                      |  Jay Pipes (<jaypipes@gmail.com>)                  |
|                      |  Ionut Artarisi (<iartarisi@suse.cz>)              |
|                      |  Salman Baset (<sabaset@us.ibm.com>)               |
|                      |  Jian Hua Geng (<gengjh@cn.ibm.com>)               |
|                      |  Chen Zhiwei (<zhiwchen@cn.ibm.com>)               |
|                      |  Mark Vanderwiel(<vanderwl@us.ibm.com>)            |
|                      |  Eric Zhou(<zyouzhou@cn.ibm.com>)                  |
|                      |  Jan Klare (<j.klare@x-ion.de>)                    |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2013, AT&T Services, Inc.           |
|                      |  Copyright (c) 2013-2014, SUSE Linux GmbH          |
|                      |  Copyright (c) 2012, Rackspace US, Inc.            |
|                      |  Copyright (c) 2013-2014, IBM Corp.                |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
