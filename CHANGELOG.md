# CHANGELOG for cookbook-openstack-network

This file is used to list changes made in each version of cookbook-openstack-network.

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
