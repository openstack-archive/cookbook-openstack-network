name             'openstack-network'
maintainer       'openstack-chef'
maintainer_email 'openstack-dev@lists.openstack.org'
license          'Apache-2.0'
description      'Installs and configures the OpenStack Network API Service and various agents and plugins'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '18.0.0'

%w(ubuntu redhat centos).each do |os|
  supports os
end

depends 'openstack-common', '>= 18.0.0'
depends 'openstack-identity', '>= 18.0.0'
depends 'openstackclient'

issues_url 'https://launchpad.net/openstack-chef' if respond_to?(:issues_url)
source_url 'https://github.com/openstack/cookbook-openstack-network' if respond_to?(:source_url)
chef_version '>= 12.5' if respond_to?(:chef_version)
