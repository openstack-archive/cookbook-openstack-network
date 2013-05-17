Description
===========

Installs the OpenStack Network service **Quantum** as part of the OpenStack reference deployment Chef for OpenStack. The http://github.com/mattray/chef-openstack-repo contains documentation for using this cookbook in the context of a full OpenStack deployment. Quantum is currently installed from packages.

https://wiki.openstack.org/wiki/Quantum

Requirements
============

Cookbooks
---------

Usage
=====

Attributes
==========

Testing
=====

This cookbook is using [ChefSpec](https://github.com/acrmp/chefspec) for testing. Run the following before commiting. It will run your tests, and check for lint errors.

    $ ./run_tests.bash

License and Author
==================

|                      |                                                    |
|:---------------------|:---------------------------------------------------|
| **Author**           |  Matt Ray (<matt@opscode.com>)                     |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2013, Opscode, Inc.                 |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and⋅
limitations under the License.
