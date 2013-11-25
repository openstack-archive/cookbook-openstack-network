require_relative "spec_helper"

describe "openstack-network::identity_registration" do
  before do
    neutron_stubs
    @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
        n.set["openstack"]["compute"]["network"]["service_type"] = "neutron"
      end
    @chef_run.converge "openstack-network::identity_registration"
  end

  it "does not do network service registrations when nova networking" do
    @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
    node = @chef_run.node
    node.set["openstack"]["compute"]["network"]["service_type"] = "nova"
    @chef_run.converge "openstack-network::identity_registration"

    resource = @chef_run.find_resource(
      "openstack-identity_register",
      "Register Network API Service"
    )

    expect(resource).to be_nil
  end

  it "registers network service" do
    resource = @chef_run.find_resource(
      "openstack-identity_register",
      "Register Network API Service"
    ).to_hash

    expect(resource).to include(
      :auth_uri => "http://127.0.0.1:35357/v2.0",
      :bootstrap_token => "bootstrap-token",
      :service_type => "network",
      :service_description => "OpenStack Network Service",
      :action => [:create_service]
    )
  end

  it "registers network endpoint" do
    resource = @chef_run.find_resource(
      "openstack-identity_register",
      "Register Network Endpoint"
    ).to_hash

    expect(resource).to include(
      :auth_uri => "http://127.0.0.1:35357/v2.0",
      :bootstrap_token => "bootstrap-token",
      :service_type => "network",
      :endpoint_region => "RegionOne",
      :endpoint_adminurl => "http://127.0.0.1:9696",
      :endpoint_internalurl => "http://127.0.0.1:9696",
      :endpoint_publicurl => "http://127.0.0.1:9696",
      :action => [:create_endpoint]
    )
  end

  it "registers service tenant" do
    resource = @chef_run.find_resource(
      "openstack-identity_register",
      "Register Service Tenant"
    ).to_hash

    expect(resource).to include(
      :auth_uri => "http://127.0.0.1:35357/v2.0",
      :bootstrap_token => "bootstrap-token",
      :tenant_name => "service",
      :tenant_description => "Service Tenant",
      :action => [:create_tenant]
    )
  end

  it "registers service user" do
    resource = @chef_run.find_resource(
      "openstack-identity_register",
      "Register neutron User"
    ).to_hash

    expect(resource).to include(
      :auth_uri => "http://127.0.0.1:35357/v2.0",
      :bootstrap_token => "bootstrap-token",
      :tenant_name => "service",
      :user_name => "neutron",
      :user_pass => "neutron-pass",
      :action => [:create_user]
    )
  end

  it "grants admin role to service user for service tenant" do
    resource = @chef_run.find_resource(
      "openstack-identity_register",
      "Grant 'admin' Role to neutron User for service Tenant"
    ).to_hash

    expect(resource).to include(
      :auth_uri => "http://127.0.0.1:35357/v2.0",
      :bootstrap_token => "bootstrap-token",
      :tenant_name => "service",
      :role_name => "admin",
      :user_name => "neutron",
      :action => [:grant_role]
    )
  end
end
