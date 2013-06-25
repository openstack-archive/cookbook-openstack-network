name              "openstack-network"
maintainer        "Jay Pipes <jaypipes@gmail.com>"
license           "Apache 2.0"
description       "Installs and configures the OpenStack Network API Service and various agents and plugins"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "7.0.0"
recipe            "openstack-network::server", "Installs packages required for a OpenStack Network server"
recipe            "openstack-network::db", "Creates the OpenStack Network database"
recipe            "openstack-network::identity_registration", "Registers OpenStack Network endpoints and service user with Keystone"

%w{ ubuntu fedora redhat centos }.each do |os|
  supports os
end

depends           "database"
depends           "openstack-identity", "~> 7.0"
depends           "mysql"
depends           "openstack-common", "~> 0.2.0"
