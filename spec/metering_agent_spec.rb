# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::metering_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it do
      %w(neutron-metering-agent)
        .each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end

    describe 'metering_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/metering_agent.ini') }
      it do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 00640
        )
      end

      it do
        [
          /^interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver$/,
          /^driver = neutron.services.metering.drivers.iptables.iptables_driver.IptablesMeteringDriver$/
        ].each do |line|
          expect(chef_run).to render_file(file.name).with_content(line)
        end
      end
      it do
        expect(chef_run).to enable_service('neutron-metering-agent')
      end
    end
  end
end
