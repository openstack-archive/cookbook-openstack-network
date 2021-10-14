name             'openstack-network'
maintainer       'openstack-chef'
maintainer_email 'openstack-discuss@lists.openstack.org'
license          'Apache-2.0'
description      'Installs and configures the OpenStack Network API Service and various agents and plugins'
version          '20.0.0'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'openstackclient'
depends 'openstack-common', '>= 20.0.0'
depends 'openstack-identity', '>= 20.0.0'

issues_url 'https://launchpad.net/openstack-chef'
source_url 'https://opendev.org/openstack/cookbook-openstack-network'
chef_version '>= 16.0'
