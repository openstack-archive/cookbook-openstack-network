# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-network::nuage' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['core_plugin'] = 'neutron.plugins.nuage.plugin.NuagePlugin'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    context "when recipes include 'openstack-compute::compute" do
      before do
        allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-compute::compute').and_return(true)
        allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-network::server').and_return(false)
      end

      it 'upgarde and configure nuage plugin on compute' do
        expect(chef_run).to upgrade_package('nuage-metadata-agent')
        expect(chef_run).to upgrade_package('nuage-openvswitch')
      end

      it 'verify ruby block execution of insert controllers' do
        expect(chef_run).to run_ruby_block('insert_controllers')
      end

      describe '/etc/default/nuage-metadata-agent' do
        let(:file) { chef_run.template('/etc/default/nuage-metadata-agent') }

        it 'creates nuage-metadata-agent' do
          expect(chef_run).to create_template(file.name).with(
            user: 'neutron',
            group: 'neutron',
            mode: 0644
          )
        end

        context 'template contents' do
          it_behaves_like 'custom template banner displayer' do
            let(:file_name) { file.name }
          end

          it 'set the MATADATA_PORT atturbute' do
            node.set['openstack']['network']['nuage']['metadata_port'] = '9697'
            expect(chef_run).to render_file(file.name).with_content(/^METADATA_PORT=9697$/)
          end

          it 'has default NOVA_MATADATE_IP and NOVA_METADATA_PORT options set' do
            [/^NOVA_METADATA_IP=127.0.0.1$/, /^NOVA_METADATA_PORT=8775$/].each do |line|
              expect(chef_run).to render_file(file.name).with_content(line)
            end
          end

          it 'set the METADATA_PROXY_SHARED_SECRET attributes' do
            node.set['openstack']['network']['metadata']['secret_name'] = 'network_metadata_secret'
            allow_any_instance_of(Chef::Recipe).to receive(:get_password)
              .with('token', 'network_metadata_secret')
              .and_return('network_metadata_secret_value')
            expect(chef_run).to render_file(file.name).with_content(/^METADATA_PROXY_SHARED_SECRET=network_metadata_secret_value$/)
          end

          it 'set the NOVA_CLIENT_VERSION attributes' do
            expect(chef_run).to render_file(file.name).with_content(/^NOVA_CLIENT_VERSION=2$/)
          end

          it 'set the NOVA_OS_USERNAME attributes' do
            node.set['openstack']['network']['service_user'] = 'neutron'
            expect(chef_run).to render_file(file.name).with_content(/^NOVA_OS_USERNAME=neutron$/)
          end

          it 'set the NOVA_OS_PASSWORD attributes' do
            allow_any_instance_of(Chef::Recipe).to receive(:get_password)
              .with('service', 'openstack-network')
              .and_return('admin_password_value')
            expect(chef_run).to render_file(file.name).with_content(/^NOVA_OS_PASSWORD=admin_password_value$/)
          end

          it 'set the NOVA_OS_TENANT_NAME attributes' do
            node.set['openstack']['network']['service_tenant_name'] = 'admin'
            expect(chef_run).to render_file(file.name).with_content(/^NOVA_OS_TENANT_NAME=admin$/)
          end

          it 'sets the NOVA_OS_AUTH_URL attribute' do
            expect(chef_run).to render_file(file.name).with_content(%r{^NOVA_OS_AUTH_URL=http://127.0.0.1:5000/v2.0$})
          end

          it 'set the NUAGE_METADATA_AGENT_START_WITH_OVS attributes' do
            node.set['openstack']['network']['nuage']['metadata_start_with_vrs'] = true
            expect(chef_run).to render_file(file.name).with_content(/^NUAGE_METADATA_AGENT_START_WITH_OVS=true$/)
          end

          it 'set the NOVA_API_ENDPOINT_TYPE attributes' do
            node.set['openstack']['network']['nuage']['nova_api_endpoint_type'] = 'internalURL'
            expect(chef_run).to render_file(file.name).with_content(/^NOVA_API_ENDPOINT_TYPE=internalURL$/)
          end

          it 'set the NOVA_REGION_NAME attributes' do
            node.set['openstack']['network']['region'] = 'RegionOne'
            expect(chef_run).to render_file(file.name).with_content(/^NOVA_REGION_NAME=RegionOne$/)
          end
        end
      end

      it 'start the openvswitch service' do
        expect(chef_run).to restart_service('openvswitch')
      end
    end
  end
end
