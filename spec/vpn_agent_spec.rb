# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::vpn_agent' do

  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['enable_vpn'] = true
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'include the recipe openstack-network::l3_agent' do
      expect(chef_run).to include_recipe('openstack-network::l3_agent')
    end

    it 'verify l3 agent is stoped and disabled' do
      expect(chef_run).to stop_service('neutron-l3-agent')
      expect(chef_run).to disable_service('neutron-l3-agent')
    end

    it 'upgrades neutron vpn package' do
      expect(chef_run).to upgrade_package('neutron-vpn-agent')
    end

    it 'starts the vpn agent on boot' do
      expect(chef_run).to enable_service('neutron-vpn-agent')
    end

    it 'subscribes the vpn agent service to neutron.conf' do
      expect(chef_run.service('neutron-vpn-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    describe 'vpn_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/vpn_agent.ini') }

      it 'creates vpn_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end

      it 'notifies the vpn agent service' do
        expect(file).to notify('service[neutron-vpn-agent]').to(:restart).immediately
      end
    end
  end
end
