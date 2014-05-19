# CHANGELOG for cookbook-openstack-network
This file is used to list changes made in each version of cookbook-openstack-network.
## 9.0.8
* Add support for miscellaneous options (like in Compute)

## 9.0.7
* Revert Switch to using auth_url instead of auth_host et al

## 9.0.6
* Fix ovs_use_veth default value

## 9.0.5
* Switch to using auth_url instead of auth_host et al

## 9.0.4
* Fix to allow build openvswitch spec to work on windows

## 9.0.3
* Fix openvswitch and linuxbridge agent

## 9.0.2
* Fix to allow data network openvswitch bridge to be created

## 9.0.1
* Fix package action to allow updates

## 9.0.0
* Upgrade to Icehouse
* The balancer recipe now includes openstack-network::common
* Neutron agents now subscribe to changes in neutron.conf
* Add rpc attributes
* Remove policy file

## 8.5.1
### Bug
* Fix the DB2 ODBC driver issue

## 8.5.0
### Blue print
* Use the library method auth_uri_transform

## 8.4.0
* Add new template for ml2 plugin

## 8.3.0
* Add new attributes to support vxlan in linuxbridge plugin template

## 8.2.0
* Move the database section into neutron.conf from plugins
* Make the service_provider attribute configurable

## 8.1.1
* allow dnsmasq source build to be optional

## 8.1.0
* Add client recipe

## 8.0.1:
* Add network database migration
* Remove unneeded and redundant rhel setup script calls
* Deprecate node['openstack']['network']['neutron_loadbalancer'] in favor of
  node['openstack']['network']['service_plugins']

## 8.0.0:
* Support neutron deployment by search and replace quantum with neutron

## 7.1.1
* fixing rpc_backend for qpid

## 7.1.0
* adding qpid support to quantum. default is rabbitmq

## 7.0.5
* Parameterize quota default values in quantum.conf.erb (LP #1228623)

## 7.0.4
* Set auth_uri and use admin_endpoint in authtoken configuration (LP #1207504)

## 7.0.3:
* Parameterize agent_down_time and report_interval settings

## 7.0.2:
* Add delay to quantum-ha-tool.py script to prevent aggressive migrations

## 7.0.1:
* Allow quota driver to be set dynamically (LP #1234324)

## 7.0.0:
* Start Grizzly + Neutron deployment
