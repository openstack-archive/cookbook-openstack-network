# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network_l3']['external_network_bridge_interface'] = 'eth1'

      runner.converge(described_recipe)
    end
    describe 'recipe' do
      include_context 'neutron-stubs'

      it 'starts the l3 agent on boot' do
        expect(chef_run).to enable_service('neutron-l3-agent')
      end

      it 'subscribes the l3 agent service to neutron.conf' do
        expect(chef_run.service('neutron-l3-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
      end
      %w(neutron-l3-agent radvd keepalived).each do |pkg|
        it "upgrades #{pkg} package" do
          expect(chef_run).to upgrade_package(pkg)
        end
      end

      describe 'l3_agent.ini' do
        let(:file) { chef_run.template('/etc/neutron/l3_agent.ini') }

        it 'creates l3_agent.ini' do
          expect(chef_run).to create_template(file.name).with(
            user: 'neutron',
            group: 'neutron',
            mode: 0640
          )
        end

        context 'template contents' do
          it_behaves_like 'common network attributes displayer', 'l3' do
            let(:file_name) { file.name }
          end

          it 'displays the external_network_bridge l3 attribute' do
            node.set['openstack']['network_l3']['conf']['DEFAULT']['external_network_bridge'] = 'network_l3_external_network_bridge_value'
            stub_command('ovs-vsctl br-exists network_l3_external_network_bridge_value').and_return(false)
            expect(chef_run).to render_file(file.name).with_content(/^external_network_bridge = network_l3_external_network_bridge_value$/)
          end
        end

        it 'notifies the l3 agent service' do
          expect(file).to notify('service[neutron-l3-agent]').to(:restart).delayed
        end
      end
    end
    describe 'create ovs bridges' do
      let(:cmd) { 'ovs-vsctl add-br br-ex' }
      let(:create_ex_br_name) { 'create external network bridge' }
      let(:enable_ex_br_int_name) { 'enable external_network_bridge_interface' }
      let(:iplink) { 'ip link set eth1 up && ovs-vsctl --may-exist add-port br-ex eth1' }
      include_context 'neutron-stubs'
      context 'interface driver unset' do
        before do
          node.set['openstack']['network_l3']['conf']['DEFAULT']['interface_driver'] = nil
        end
      end
      context 'interface driver set' do
        before do
          node.set['openstack']['network_l3']['conf']['DEFAULT']['interface_driver'] =
            'neutron.agent.linux.interface.OVSInterfaceDriver'
        end
        context 'ext_bridge and ext_bridge_iface unset' do
          before do
            node.set['openstack']['network_l3']['conf']['DEFAULT']['external_network_bridge'] = nil
            node.set['openstack']['network_l3']['external_network_bridge_interface'] = nil
          end
        end
        context 'ext_bridge and ext_bridge_iface are set' do
          before do
            node.set['openstack']['network_l3']['conf']['DEFAULT']['external_network_bridge'] = 'br-ex'
            node.set['openstack']['network_l3']['external_network_bridge_interface'] = 'eth1'
            stub_command(/ovs-vsctl add-br br-ex/)
          end
          context 'ext_bridge exists' do
            before do
              stub_command(/ovs-vsctl br-exists br-ex/).and_return(true)
            end
            it 'does not add ext_bridge' do
              expect(chef_run).not_to run_execute(create_ex_br_name)
            end
          end
          context 'ext_bridge doesnt exists' do
            before do
              stub_command(/ovs-vsctl br-exists br-ex/).and_return(false)
            end
            it 'does add ext_bridge' do
              expect(chef_run).to run_execute(create_ex_br_name)
            end
          end
          context 'ext_bridge_iface exists' do
            before do
              stub_command(/ip link show eth1/).and_return(true)
            end
            it 'does enable ext_bridge_iface' do
              expect(chef_run).to run_execute(enable_ex_br_int_name)
            end
          end
          context 'ext_bridge_iface doesnt exists' do
            before do
              stub_command(/ip link show eth1/).and_return(false)
            end
            it 'does not enable ext_bridge_iface' do
              expect(chef_run).not_to run_execute(enable_ex_br_int_name)
            end
          end
        end
      end
    end
  end
end
