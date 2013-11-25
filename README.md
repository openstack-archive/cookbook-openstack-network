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

* identity
* openstack-common `>= 2.0.0`

Recipes
=======

server
------

- Installs the openstack-network API server

dhcp\_agent
--------

- Installs the DHCP agent

l3\_agent
--------

- Installs the L3 agent and metadata agent

Identity-registration
---------------------

- Registers the OpenStack Network API endpoint and service user with Keystone

Attributes
==========

TODO

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


Templates
=========

* `api-paste.ini.erb` - Paste config for OpenStack Network server
* `neutron.conf.erb` - Config file for OpenStack Network server
* `policy.json.erb` - Configuration of ACLs for glance API server

Testing
=======

This cookbook uses [bundler](http://gembundler.com/), [berkshelf](http://berkshelf.com/), and [strainer](https://github.com/customink/strainer) to isolate dependencies and run tests.

Tests are defined in Strainerfile.

To run tests:

    $ bundle install # install gem dependencies
    $ bundle exec berks install # install cookbook dependencies
    $ bundle exec strainer test # run tests

License and Author
==================

|                      |                                                    |
|:---------------------|:---------------------------------------------------|
| **Authors**          |  Alan Meadows (<alan.meadows@gmail.com>)           |
|                      |  Jay Pipes (<jaypipes@gmail.com>)                  |
|                      |  Ionut Artarisi (<iartarisi@suse.cz>)              |
|                      |  Salman Baset (<sabaset@us.ibm.com>)               |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2013, AT&T Services, Inc.           |
|                      |  Copyright (c) 2013, SUSE Linux GmbH               |
|                      |  Copyright (c) 2012, Rackspace US, Inc.            |
|                      |  Copyright (c) 2013, IBM Corp.                     |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
