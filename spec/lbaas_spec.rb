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
        neutron-lbaasv2-agent
        python3-neutron-lbaas
      )
    it do
      expect(chef_run).to upgrade_package(pkgs)
    end

    it do
      expect(chef_run).to create_directory('/etc/neutron/conf.d/neutron-server').with(recursive: true)
    end

    describe '/etc/neutron/lbaas_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/lbaas_agent.ini') }
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
        expect(file).to notify('service[neutron-lb-agent]').to(:restart)
      end

      [
        /^interface_driver = openvswitch$/,
        /^device_driver = neutron_lbaas.drivers.haproxy.namespace_driver.HaproxyNSDriver$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', line)
        end
      end
      [
        /^user_group = nogroup$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('haproxy', line)
        end
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
      %w(
        template[/etc/neutron/neutron.conf]
        template[/etc/neutron/conf.d/neutron-server/neutron_lbaas.conf]
      ).each do |resource|
        it do
          expect(chef_run.service('neutron-lb-agent')).to subscribe_to(resource).on(:restart)
        end
      end
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
