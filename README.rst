OpenStack Chef Cookbook - network
=================================

.. image:: https://governance.openstack.org/badges/cookbook-openstack-network.svg
    :target: https://governance.openstack.org/reference/tags/index.html

Description
===========

This cookbook installs the OpenStack Network service **Neutron** as part
of a Chef reference deployment of OpenStack. The `OpenStack chef-repo`_
contains documentation for using this cookbook in the context of a full
OpenStack deployment. Neutron is currently installed from packages.

.. _OpenStack chef-repo: https://opendev.org/openstack/openstack-chef

https://docs.openstack.org/neutron/latest/

Usage
=====

OpenStack Network's design is modular, with plugins available that
handle L2 and L3 networking for various hardware vendors and standards.

Requirements
============

- Chef 15 or higher
- Chef Workstation 20.8.111 for testing (also includes Berkshelf for
  cookbook dependency resolution)

Platform
========

- ubuntu
- redhat
- centos

Cookbooks
=========

The following cookbooks are dependencies:

- 'openstackclient'
- 'openstack-common', '>= 20.0.0'
- 'openstack-identity', '>= 20.0.0'

Attributes
==========

Please see the extensive inline documentation in ``attributes/*.rb`` for
descriptions of all the settable attributes for this cookbook.

Note that all attributes are in the ``default['openstack']`` "namespace"

The usage of attributes to generate the ``neutron.conf`` is described in
the openstack-common cookbook.

Recipes
=======

openstack-network::_bridge_config_example
-----------------------------------------

- Example bridge recipe used in kitchen tests

openstack-network::db_migration
-------------------------------

- Migrates the neutron database

openstack-network::default
--------------------------

- Configures common pieces needed for all neutron services and create
  the ``neutron.conf``

openstack-network::dhcp_agent
-----------------------------

-  Installs the DHCP agent

The configuration for ``neutron-dhcp-agent`` is generated from the
attributes in using the same template as for the ``neutron.conf``

.. code-block:: ruby

    node['openstack']['network_dhcp']['conf']

openstack-network::identity_registration
----------------------------------------

-  Registers the OpenStack Network API endpoint and service user with
   Keystone

openstack-network::l3_agent
---------------------------

-  Installs the L3 agent

The configuration for ``neutron-l3-agent`` is generated from the
attributes in using the same template as for the ``neutron.conf``

.. code-block:: ruby

    node['openstack']['network_l3']['conf']

openstack-network::metadata_agent
---------------------------------

-  Installs the metadata agent

The configuration for ``neutron-metadata-agent`` is generated from the
attributes in using the same template as for the ``neutron.conf``

.. code-block:: ruby

    node['openstack']['network_metadata']['conf']

openstack-network::metering_agent
---------------------------------

-  Installs the metering agent

The configuration for ``neutron-metadata-agent`` is generated from the
attributes in using the same template as for the ``neutron.conf``

.. code-block:: ruby

    node['openstack']['network_metering']['conf']

openstack-network::ml2_core_plugin
----------------------------------

-  Configure the ``ml2_core_plugin``

openstack-network::ml2_linuxbridge
----------------------------------

-  Configure the ml2 linuxbridge plugin

openstack-network::ml2_openvswitch
----------------------------------

-  Configure the ml2 openvswitch plugin

openstack-network::openvswitch
------------------------------

-  Installs openvswitch

openstack-network::openvswitch_agent
------------------------------------

-  Installs the openvswitch agent

openstack-network::plugin_config
--------------------------------

-  Generates all the needed plugin configurations directly from the
   attributes in:

.. code-block:: ruby

    node['openstack']['network']['plugins'][myplugin]

The final configuration file is generated exactly like all OpenStack
service configuration files (e.g. ``neutron.conf``), but the attribute
mentioned above allows you additionally to define the file name and
patch with:

.. code-block:: ruby

  # this will also generate the path recursively if not already existent
  node['openstack']['network']['plugins'][myplugin]['path']
  # this defines the filename for the plugin config (e.g. ml2_conf.ini)
  node['openstack']['network']['plugins'][myplugin]['filename']

In the examples above, the variable ``myplugin`` can be used to generate
multiple plugin configurations with different configs and filenames.
Please refer to the recipe ``openstack-network::ml2_openvswitch`` for an
full example on the usage of this attributes.

openstack-network::server
-------------------------

-  Installs the openstack-network API server (currently aka
   neutron-server)

License and Author
==================

+-----------------+--------------------------------------------+
| **Authors**     | Alan Meadows (alan.meadows@gmail.com)      |
+-----------------+--------------------------------------------+
| **Authors**     | Jay Pipes (jaypipes@gmail.com)             |
+-----------------+--------------------------------------------+
| **Authors**     | Ionut Artarisi (iartarisi@suse.cz)         |
+-----------------+--------------------------------------------+
| **Authors**     | Salman Baset (sabaset@us.ibm.com)          |
+-----------------+--------------------------------------------+
| **Authors**     | Jian Hua Geng (gengjh@cn.ibm.com)          |
+-----------------+--------------------------------------------+
| **Authors**     | Chen Zhiwei (zhiwchen@cn.ibm.com)          |
+-----------------+--------------------------------------------+
| **Authors**     | Mark Vanderwiel(vanderwl@us.ibm.com)       |
+-----------------+--------------------------------------------+
| **Authors**     | Eric Zhou(zyouzhou@cn.ibm.com)             |
+-----------------+--------------------------------------------+
| **Authors**     | Jan Klare (j.klare@x-ion.de)               |
+-----------------+--------------------------------------------+
| **Authors**     | Christoph Albers (c.albers@x-ion.de)       |
+-----------------+--------------------------------------------+
| **Authors**     | Lance Albertson (lance@osuosl.org)         |
+-----------------+--------------------------------------------+

+-----------------+--------------------------------------------------+
| **Copyright**   | Copyright (c) 2013, AT&T Services, Inc.          |
+-----------------+--------------------------------------------------+
| **Copyright**   | Copyright (c) 2013-2014, SUSE Linux GmbH         |
+-----------------+--------------------------------------------------+
| **Copyright**   | Copyright (c) 2012, Rackspace US, Inc.           |
+-----------------+--------------------------------------------------+
| **Copyright**   | Copyright (c) 2013-2014, IBM Corp.               |
+-----------------+--------------------------------------------------+
| **Copyright**   | Copyright (c) 2016, cloudbau GmbH                |
+-----------------+--------------------------------------------------+
| **Copyright**   | Copyright (c) 2016-2020, Oregon State University |
+-----------------+--------------------------------------------------+

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

::

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
