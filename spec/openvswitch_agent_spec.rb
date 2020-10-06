require_relative 'spec_helper'

describe 'openstack-network::openvswitch_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['network']['openvswitch']['integration_bridge'] = 'br-int'
      runner.converge(described_recipe, 'openstack-network::plugin_config')
    end

    include_context 'neutron-stubs'

    before do
      stub_command('ovs-vsctl --may-exist add-br br-int')
    end

    it do
      expect(chef_run).to upgrade_package 'neutron-openvswitch-agent'
    end

    it do
      expect(chef_run).to run_execute('create integration network bridge')
        .with(command: 'ovs-vsctl --may-exist add-br br-int')
    end

    it do
      expect(chef_run).to enable_service('neutron-openvswitch-agent').with(
        service_name: 'neutron-openvswitch-agent',
        supports: {
          status: true,
          restart: true,
        }
      )
    end

    it do
      expect(chef_run).to start_service 'neutron-openvswitch-agent'
    end
    %w(
      template[/etc/neutron/neutron.conf]
      template[/etc/neutron/plugins/ml2/openvswitch_agent.ini]
    ).each do |t|
      it t do
        expect(chef_run.service('neutron-openvswitch-agent')).to subscribe_to(t).on(:restart)
      end
    end
  end
end
