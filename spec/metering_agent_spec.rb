require_relative 'spec_helper'

describe 'openstack-network::metering_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to upgrade_package('neutron-metering-agent')
    end

    describe 'metering_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/metering_agent.ini') }
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
        [
          /^interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver$/,
          /^driver = neutron.services.metering.drivers.iptables.iptables_driver.IptablesMeteringDriver$/,
        ].each do |line|
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', line)
        end
      end
    end
    it do
      expect(chef_run).to enable_service('neutron-metering-agent').with(
        service_name: 'neutron-metering-agent',
        supports: {
          status: true,
          restart: true,
        }
      )
    end
    it do
      expect(chef_run).to start_service('neutron-metering-agent')
    end
    %w(template[/etc/neutron/neutron.conf] template[/etc/neutron/metering_agent.ini]).each do |resource|
      it do
        expect(chef_run.service('neutron-metering-agent')).to subscribe_to(resource).delayed
      end
    end
  end
end
