# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::lbaas' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe, 'openstack-network::ml2_core_plugin', 'openstack-network::server')
    end

    include_context 'neutron-stubs'

    pkgs =
      %w(
        haproxy
        neutron-lbaas-common
        python3-neutron-lbaas
      )
    it do
      expect(chef_run).to upgrade_package(pkgs)
    end

    it do
      expect(chef_run).to create_directory('/etc/neutron/conf.d/neutron-server').with(recursive: true)
    end
    describe '/etc/neutron/conf.d/neutron-server/neutron_lbaas.conf' do
      let(:file) { chef_run.template('/etc/neutron/conf.d/neutron-server/neutron_lbaas.conf') }
      it do
        expect(chef_run).to create_template(file.name).with(
          source: 'openstack-service.conf.erb',
          cookbook: 'openstack-common',
          user: 'neutron',
          group: 'neutron',
          mode: '640'
        )
      end

      it do
        expect(file).to notify('service[neutron-server]').to(:restart)
      end

      [
        /^service_provider = LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('service_providers', line)
        end
      end
    end
  end
end
