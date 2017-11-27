source 'https://supermarket.chef.io'

%w(common identity).each do |cookbook|
  if Dir.exist?("../cookbook-openstack-#{cookbook}")
    cookbook "openstack-#{cookbook}", path: "../cookbook-openstack-#{cookbook}"
  else
    cookbook "openstack-#{cookbook}", github: "openstack/cookbook-openstack-#{cookbook}"
  end
end

cookbook 'openstackclient',
  github: 'cloudbau/cookbook-openstackclient'

metadata
