# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do

  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['l3']['external_network_bridge_interface'] = 'eth1'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'starts the l3 agent on boot' do
      expect(chef_run).to enable_service('neutron-l3-agent')
    end

    it 'subscribes the l3 agent service to neutron.conf' do
      expect(chef_run.service('neutron-l3-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    it 'does not install neutron l3 package when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('neutron-l3-agent')
    end

    it 'upgrades neutron l3 package' do
      expect(chef_run).to upgrade_package('neutron-l3-agent')
    end

    describe 'l3_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/l3_agent.ini') }

      it 'creates l3_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it 'it has ovs driver' do
        expect(chef_run).to render_file(file.name).with_content(
          'interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver')
      end

      it 'sets fuzzy delay to default' do
        expect(chef_run).to render_file(file.name).with_content(
          'periodic_fuzzy_delay = 5')
      end

      it 'it does not set a nil router_id' do
        expect(chef_run).not_to render_file(file.name).with_content(/^router_id =/)
      end

      it 'it does not set a nil router_id' do
        expect(chef_run).not_to render_file(file.name).with_content(
          /^gateway_external_network_id =/)
      end

      it 'notifies the l3 agent service' do
        expect(file).to notify('service[neutron-l3-agent]').to(:restart).immediately
      end
    end

    describe 'create ovs bridges' do
      let(:cmd) { 'ovs-vsctl add-br br-ex && ovs-vsctl add-port br-ex eth1' }

      it "doesn't add the external bridge if it already exists" do
        stub_command(/ovs-vsctl br-exists/).and_return(true)
        stub_command(/ip link show eth1/).and_return(true)

        expect(chef_run).not_to run_execute(cmd)
      end

      it "doesn't add the external bridge if the physical interface doesn't exist" do
        stub_command(/ovs-vsctl br-exists/).and_return(true)
        stub_command(/ip link show eth1/).and_return(false)

        expect(chef_run).not_to run_execute(cmd)
      end

      it 'adds the external bridge if it does not yet exist' do
        stub_command(/ovs-vsctl br-exists/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)

        expect(chef_run).to run_execute(cmd)
      end

      it 'adds the external bridge if the physical interface exists' do
        stub_command(/ovs-vsctl br-exists/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)

        expect(chef_run).to run_execute(cmd)
      end
    end
  end
end
