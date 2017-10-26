# attribute can be used in wrapper cookbooks to handover secrets (will not be
# saved after successfull chef run)
default['openstack']['network']['conf_secrets'] = {}

default['openstack']['network']['conf'].tap do |conf|
  # [DEFAULT] section
  if node['openstack']['network']['syslog']['use']
    conf['DEFAULT']['log_config_append'] = '/etc/openstack/logging.conf'
  else
    conf['DEFAULT']['log_dir'] = '/var/log/neutron'
  end
  conf['DEFAULT']['control_exchange'] = 'neutron'
  conf['DEFAULT']['core_plugin'] = 'ml2'

  # [agent] section
  if node['openstack']['network']['use_rootwrap']
    conf['agent']['root_helper'] = 'sudo neutron-rootwrap /etc/neutron/rootwrap.conf'
  end

  # [keystone_authtoken] section
  conf['keystone_authtoken']['auth_type'] = 'v3password'
  conf['keystone_authtoken']['region_name'] = node['openstack']['region']
  conf['keystone_authtoken']['username'] = 'neutron'
  conf['keystone_authtoken']['user_domain_name'] = 'Default'
  conf['keystone_authtoken']['project_domain_name'] = 'Default'
  conf['keystone_authtoken']['project_name'] = 'service'
  conf['keystone_authtoken']['auth_version'] = 'v3'
  # [nova] section
  conf['nova']['auth_type'] = 'v3password'
  conf['nova']['region_name'] = node['openstack']['region']
  conf['nova']['username'] = 'nova'
  conf['nova']['user_domain_name'] = 'Default'
  conf['nova']['project_name'] = 'service'
  conf['nova']['project_domain_name'] = 'Default'

  # [oslo_concurrency] section
  conf['oslo_concurrency']['lock_path'] = '/var/lib/neutron/lock'
end
