# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::lbaas' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      node.override['openstack']['network']['lbaas']['enabled'] = 'True'
      runner.converge(described_recipe, 'openstack-network::ml2_core_plugin', 'openstack-network::server')
    end

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to_not create_directory('/etc/neutron/conf.d/neutron-server')
    end

    describe 'lbaas_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/lbaas_agent.ini') }

      it do
        expect(chef_run).to render_config_file(file.name).with_section_content('haproxy', /^user_group = nobody$/)
      end
    end

    pkgs =
      %w(
        haproxy
        iproute
        openstack-neutron-lbaas
      )
    it do
      expect(chef_run).to upgrade_package(pkgs)
    end

    it do
      expect(chef_run).to enable_service('neutron-lb-agent').with(
        service_name: 'neutron-lbaasv2-agent',
        supports: {
          status: true,
          restart: true,
        }
      )
    end
  end
end
