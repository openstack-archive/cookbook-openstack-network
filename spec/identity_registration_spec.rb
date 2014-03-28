# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::identity_registration' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not do network service registrations when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).not_to create_service_openstack_identity_register(
        'Register Network API Service'
      )
    end

    it 'registers network service' do
      expect(chef_run).to create_service_openstack_identity_register(
        'Register Network API Service'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'network',
        service_description: 'OpenStack Network Service'
      )
    end

    context 'registers network endpoint' do
      it 'with default values' do
        expect(chef_run).to create_endpoint_openstack_identity_register(
          'Register Network Endpoint'
        ).with(
          auth_uri: 'http://127.0.0.1:35357/v2.0',
          bootstrap_token: 'bootstrap-token',
          service_type: 'network',
          endpoint_region: 'RegionOne',
          endpoint_adminurl: 'http://127.0.0.1:9696',
          endpoint_internalurl: 'http://127.0.0.1:9696',
          endpoint_publicurl: 'http://127.0.0.1:9696'
        )
      end

      it 'with custom region override' do
        node.set['openstack']['network']['region'] = 'netRegion'

        expect(chef_run).to create_endpoint_openstack_identity_register(
          'Register Network Endpoint'
        ).with(endpoint_region: 'netRegion')
      end
    end

    it 'registers service tenant' do
      expect(chef_run).to create_tenant_openstack_identity_register(
        'Register Service Tenant'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        tenant_name: 'service',
        tenant_description: 'Service Tenant'
      )
    end

    it 'registers service user' do
      expect(chef_run).to create_user_openstack_identity_register(
        'Register neutron User'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        tenant_name: 'service',
        user_name: 'neutron',
        user_pass: 'neutron-pass'
      )
    end

    it 'grants admin role to service user for service tenant' do
      expect(chef_run).to grant_role_openstack_identity_register(
        "Grant 'admin' Role to neutron User for service Tenant"
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        tenant_name: 'service',
        role_name: 'admin',
        user_name: 'neutron'
      )
    end
  end
end
