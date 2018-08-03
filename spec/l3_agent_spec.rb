# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.override['openstack']['network_l3']['external_network_bridge_interface'] = 'enp0s8'
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
            mode: 0o640
          )
        end

        context 'template contents' do
          it_behaves_like 'common network attributes displayer', 'l3' do
            let(:file_name) { file.name }
          end

          it 'displays the external_network_bridge l3 attribute' do
            node.override['openstack']['network_l3']['conf']['DEFAULT']['external_network_bridge'] = 'network_l3_external_network_bridge_value'
            stub_command('ovs-vsctl br-exists network_l3_external_network_bridge_value').and_return(false)
            expect(chef_run).to render_file(file.name).with_content(/^external_network_bridge = network_l3_external_network_bridge_value$/)
          end
        end

        it 'notifies the l3 agent service' do
          expect(file).to notify('service[neutron-l3-agent]').to(:restart).delayed
        end
      end
    end
  end
end
