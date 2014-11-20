# CHANGELOG for cookbook-openstack-network
This file is used to list changes made in each version of cookbook-openstack-network.

## 10.1.0
* Add support for Neutron VPN Service
* Remove Neutron DB stamp and upgrade to head.
* Add attribute for ML2 enable_ipset
* Bump Chef gem to 11.16
* Add attributes for api_workers and rpc_workers
* Add attributes for quota_router and quota_floatingip
* Allow specifying the L3 agents' gateway_external_network by name.
* Add nova_ca_certificates_file and nova_api_insecure; change nova_url to use the correct scheme
* Fixed midonet and metaplugin plugin configuration file rendering
* Make auth_version to be v2.0 in configuration file
* Added directory resource for neutron_ha_cmd
* Add cacert,insecure arguments for get nova_admin_tenant_id call
* Add multi driver support and package dependencies to vpn_agent recipe
* Enable services required by vpn drivers
* Set the external physical interface to up

## 10.0.1
* Add tunnel_types item in ovs_neutron_plugin.ini.erb
* Update neutron.conf from mode 0644 to 0640
* Add cafile, memcached_servers, memcache_security_strategy, memcache_secret_key, insecure and hash_algorithms so that they are configurable.

## 10.0.0
* Upgrading to Juno
* Sync conf files with Juno
* Upgrading berkshelf from 2.0.18 to 3.1.5

## 9.1.1
* Allow dhcp_delete_namespaces and router_dhcp_namespaces to be overridden.
* Add support for openvswitch agent MTU size of veth interfaces
* fix fauxhai version for suse and redhat
* Allow rootwrap.conf attributes

## 9.1.0
* python_packages database client attributes have been migrated to
the -common cookbook
* bump berkshelf to 2.0.18 to allow Supermarket support
* Add rabbit_use_ssl configuration item.

## 9.0.10
* Start the neutron server service after installed

## 9.0.9
* Fix to plugin.ini symlink not updated properly when main plugin changes

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
