# TODO(jklare) : check why the package is installed and if the configuration
# works at all (if so, this needs refactoring parallel to the lbaas and vpnaas
# recipes and attributes)
# ---- moved from templates/default/services/neutron-fwaas/fwaas_driver.ini.erb----
# <%= node["openstack"]["network"]["custom_template_banner"] %>
# [fwaas]
# driver = <%= node['openstack']['network']['fwaas']['driver'] %>
# enabled = <%= node['openstack']['network']['fwaas']['enabled'] %>
# ---- moved from templates/default/services/neutron-fwaas/fwaas_driver.ini.erb----
# ---- moved from recipes/l3_agent----
# As the fwaas package will be installed anyway, configure its config-file attributes following environment.
# template node['openstack']['network']['fwaas']['config_file'] do
#  source 'services/neutron-fwaas/fwaas_driver.ini.erb'
#  user node['openstack']['network']['platform']['user']
#  group node['openstack']['network']['platform']['group']
#  mode 00640
#  # Only restart vpn agent to avoid synchronization problem, when vpn agent is enabled.
#  if node['openstack']['network']['enable_vpn']
#    notifies :restart, 'service[neutron-vpn-agent]', :delayed
#  else
#    notifies :restart, 'service[neutron-l3-agent]', :immediately
#  end
# end
# ---- moved from recipes/l3_agent----
