# CHANGELOG for cookbook-openstack-network

This file is used to list changes made in each version of cookbook-openstack-network.

## 7.4.1
* Add missing quantum-ovs-cleanup to ubuntu startup (LP #1266495)

## 7.4.0
* Add network database migration

## 7.3.0
* Allow the DHCP lease timeout to be overriden in quantum.conf.erb

## 7.2.0
* Parameterize wsgi default values in quantum.conf.erb

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
