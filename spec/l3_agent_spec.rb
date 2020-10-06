require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['network_l3']['external_network_bridge_interface'] = 'enp0s8'
      runner.converge(described_recipe)
    end
    describe 'recipe' do
      include_context 'neutron-stubs'

      it do
        expect(chef_run).to enable_service('neutron-l3-agent').with(
          service_name: 'neutron-l3-agent',
          supports: {
            status: true,
            restart: true,
          }
        )
      end

      it do
        expect(chef_run).to start_service('neutron-l3-agent')
      end

      it do
        expect(chef_run.service('neutron-l3-agent')).to \
          subscribe_to('template[/etc/neutron/neutron.conf]').on(:restart)
      end

      pkgs =
        %w(
          keepalived
          neutron-l3-agent
          radvd
        )
      it do
        expect(chef_run).to upgrade_package(pkgs)
      end

      describe 'l3_agent.ini' do
        let(:file) { chef_run.template('/etc/neutron/l3_agent.ini') }

        it 'creates l3_agent.ini' do
          expect(chef_run).to create_template(file.name).with(
            source: 'openstack-service.conf.erb',
            cookbook: 'openstack-common',
            user: 'neutron',
            group: 'neutron',
            mode: '640'
          )
        end

        [
          /^interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver$/,
        ].each do |line|
          it do
            expect(chef_run).to render_config_file('/etc/neutron/l3_agent.ini').with_section_content('DEFAULT', line)
          end
        end

        context 'template contents' do
          cached(:chef_run) do
            node.override['openstack']['network_l3']['conf']['DEFAULT']['external_network_bridge'] = 'network_l3_external_network_bridge_value'
            runner.converge(described_recipe)
          end
          it_behaves_like 'common network attributes displayer', 'l3' do
            let(:file_name) { file.name }
          end

          it 'displays the external_network_bridge l3 attribute' do
            stub_command('ovs-vsctl br-exists network_l3_external_network_bridge_value').and_return(false)
            expect(chef_run).to render_config_file(file.name)
              .with_section_content(
                'DEFAULT',
                /^external_network_bridge = network_l3_external_network_bridge_value$/
              )
          end
        end

        it do
          expect(file).to notify('service[neutron-l3-agent]').to(:restart).delayed
        end
      end
    end
  end
end
