Team and repository tags
========================

[![Team and repository tags](http://governance.openstack.org/badges/cookbook-openstack-network.svg)](http://governance.openstack.org/reference/tags/index.html)

<!-- Change things from this point on -->

![Chef OpenStack Logo](https://www.openstack.org/themes/openstack/images/project-mascots/Chef%20OpenStack/OpenStack_Project_Chef_horizontal.png)

Description
===========

This cookbook installs the OpenStack Network service **Neutron** as part of a
Chef reference deployment of OpenStack. The
https://github.com/openstack/openstack-chef-repo contains documentation for using this cookbook in the context of a full OpenStack deployment.

More information about the OpenStack Network service is available
[here](http://docs.openstack.org/mitaka/config-reference/networking.html)

Usage
=====

OpenStack Network's design is modular, with plugins available that handle L2 and
L3 networking for various hardware vendors and standards.

Requirements
============

- Chef 12 or higher
- chefdk 0.9.0 or higher for testing (also includes berkshelf for cookbook
  dependency resolution)

Platform
========

- ubuntu
- redhat
- centos

Cookbooks
=========

The following cookbooks are dependencies:

- 'openstack-common', '>= 14.0.0'
- 'openstack-identity', '>= 14.0.0'
- 'openstackclient', '>= 0.1.0'

Attributes
==========

Please see the extensive inline documentation in `attributes/*.rb` for
descriptions of all the settable attributes for this cookbook.

Note that all attributes are in the `default['openstack']` "namespace"

The usage of attributes to generate the neutron.conf is described in the
openstack-common cookbook.

Recipes
=======

## openstack-network::client
- Install the network client packages

## openstack-network::db_migration
- Migrates the neutron database

## openstack-network::default
- Configures common pieces needed for all neutron services and create the
  neutron.conf

## openstack-network::dhcp_agent
- Installs the DHCP agent

The configuration for neutron-dhcp-agent is generated from the attributes in
using the same template as for the neutron.conf

```
node['openstack']['network_dhcp']['conf']
```

## openstack-network::fwaas
**This is a 'work in progress' recipe and is currently not tested**
- Installs the Firewall as a Service

## openstack-network::identity_registration
- Registers the OpenStack Network API endpoint and service user with Keystone

## openstack-network::l3_agent
- Installs the L3 agent

The configuration for neutron-l3-agent is generated from the attributes in using
the same template as for the neutron.conf

```
node['openstack']['network_l3']['conf']
```

## openstack-network::lbaas
- Installs the Loadbalancer as a Service

The configuration for neutron-lbaas-agent is generated from the attributes in
using the same template as for the neutron.conf

```
node['openstack']['network_lbaas']['conf']
```

## openstack-network::metadata_agent
- Installs the metadata agent

The configuration for neutron-metadata-agent is generated from the attributes in
using the same template as for the neutron.conf

```
node['openstack']['network_metadata']['conf']
```

## openstack-network::metering_agent
- Installs the metering agent

The configuration for neutron-metadata-agent is generated from the attributes in
using the same template as for the neutron.conf

```
node['openstack']['network_metering']['conf']
```

## openstack-network::ml2_core_plugin
- Configure the ml2_core_plugin

## openstack-network::ml2_linuxbridge
- Configure the ml2 linuxbridge plugin

## openstack-network::ml2_openvswitch
- Configure the ml2 openvswitch plugin

## openstack-network::openvswitch
- Installs openvswitch

## openstack-network::openvswitch_agent
- Installs the openvswitch agent

## openstack-network::plugin_config
- Generates all the needed plugin configurations directly from the attributes
  in:

```
node['openstack']['network']['plugins'][myplugin]
```

The final configuration file is generated exactly like all OpenStack service
configuration files (e.g. neutron.conf), but the attribute mentioned above
allows you additionally to define the file name and patch with:

```
# this will also generate the path recursively if not already existent
node['openstack']['network']['plugins'][myplugin]['path']
# this defines the filename for the plugin config (e.g. ml2_conf.ini)
node['openstack']['network']['plugins'][myplugin]['filename']
```
In the examples above, the variable 'myplugin' can be used to generate multiple
plugin configurations with different configs and filenames. Please refer to the
recipe openstack-network::ml2_openvswitch for an full example on the usage of
this attributes.

## openstack-network::server
- Installs the openstack-network API server (currently aka neutron-server)

## openstack-network::vpnaas
- Installs the VPN as a Service

The configuration for neutron-vpn-agent is generated from the attributes in
using the same template as for the neutron.conf

```
node['openstack']['network_vpnaas']['conf']
```

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
|                      |  Christoph Albers (<c.albers@x-ion.de>)            |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2013, AT&T Services, Inc.           |
|                      |  Copyright (c) 2013-2014, SUSE Linux GmbH          |
|                      |  Copyright (c) 2012, Rackspace US, Inc.            |
|                      |  Copyright (c) 2013-2014, IBM Corp.                |
|                      |  Copyright (c) 2016, cloudbau GmbH                 |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
