# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::lbaas' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it do
      %w(python-neutron-lbaas neutron-lbaas-agent haproxy)
        .each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end

    describe 'lbaas.conf' do
      let(:file) { chef_run.template('/etc/neutron/lbaas_agent.ini') }
      it do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 00640
        )
      end

      it 'blabla' do
        [
          /^periodic_interval = 10$/,
          /^ovs_use_veth = false$/,
          /^interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver$/,
          /^device_driver = neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver$/
        ].each do |line|
          expect(chef_run).to render_file(file.name).with_content(line)
        end
      end
      it do
        expect(chef_run).to enable_service('neutron-lb-agent')
      end
    end
  end
end
