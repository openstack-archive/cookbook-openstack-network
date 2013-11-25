# CHANGELOG for cookbook-openstack-network

This file is used to list changes made in each version of cookbook-openstack-network.

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
