name             'openstack-network'
maintainer       'openstack-chef'
maintainer_email 'openstack-discuss@lists.openstack.org'
license          'Apache-2.0'
description      'Installs and configures the OpenStack Network API Service and various agents and plugins'
version          '18.0.0'

recipe 'openstack-network::_bridge_config_example', 'Example bridge recipe used in kitchen tests'
recipe 'openstack-network::db_migration', 'Migrates the neutron database'
recipe 'openstack-network::default', 'Configures common pieces needed for all neutron services and create the neutron.conf'
recipe 'openstack-network::dhcp_agent', 'Installs the DHCP agent'
recipe 'openstack-network::fwaas', 'Installs the Firewall as a Service'
recipe 'openstack-network::identity_registration', 'Registers the OpenStack Network API endpoint and service user with Keystone'
recipe 'openstack-network::l3_agent', 'Installs the L3 agent'
recipe 'openstack-network::lbaas', 'Installs the Loadbalancer as a Service'
recipe 'openstack-network::metadata_agent', 'Installs the metadata agent'
recipe 'openstack-network::metering_agent', 'Installs the metering agent'
recipe 'openstack-network::ml2_core_plugin', 'Configure the ml2_core_plugin'
recipe 'openstack-network::ml2_linuxbridge', 'Configure the ml2 linuxbridge plugin'
recipe 'openstack-network::ml2_openvswitch', 'Configure the ml2 openvswitch plugin'
recipe 'openstack-network::openvswitch', 'Installs openvswitch'
recipe 'openstack-network::openvswitch_agent', 'Installs the openvswitch agent'
recipe 'openstack-network::plugin_config', 'Generates all the needed plugin configurations directly from the attributes'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'openstackclient'
depends 'openstack-common', '>= 18.0.0'
depends 'openstack-identity', '>= 18.0.0'

issues_url 'https://launchpad.net/openstack-chef'
source_url 'https://opendev.org/openstack/cookbook-openstack-network'
chef_version '>= 14.0'
