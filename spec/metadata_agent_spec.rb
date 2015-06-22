# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::metadata_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install neutron metadata agent when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package 'neutron-metadata-agent'
    end

    it 'upgrades neutron metadata agent' do
      expect(chef_run).to upgrade_package 'neutron-metadata-agent'
    end

    it 'subscribes the metadata agent service to neutron.conf' do
      expect(chef_run.service('neutron-metadata-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    describe 'metadata_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/metadata_agent.ini') }

      it 'creates metadata_agent.ini' do
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

        it 'sets the debug attribute' do
          node.set['openstack']['network']['debug'] = 'debug_value'
          expect(chef_run).to render_file(file.name).with_content(/^debug = debug_value$/)
        end

        context 'endpoint related attributes' do
          it 'sets the auth_url attribute' do
            expect(chef_run).to render_file(file.name).with_content(%r{^auth_url = http://127.0.0.1:5000/v2.0$})
          end
        end

        it 'sets the auth_region attribute' do
          node.set['openstack']['network']['region'] = 'auth_region_value'
          expect(chef_run).to render_file(file.name).with_content(/^auth_region = auth_region_value$/)
        end

        it 'sets the admin_tenant_name attribute' do
          node.set['openstack']['network']['service_tenant_name'] = 'admin_tenant_name_value'
          expect(chef_run).to render_file(file.name).with_content(/^admin_tenant_name = admin_tenant_name_value$/)
        end

        it 'sets the admin_password attribute' do
          allow_any_instance_of(Chef::Recipe).to receive(:get_password)
            .with('service', 'openstack-network')
            .and_return('admin_password_value')
          expect(chef_run).to render_file(file.name).with_content(/^admin_password = admin_password_value$/)
        end

        it 'has default metadata ip and port options set' do
          [/^nova_metadata_ip = 127.0.0.1$/,
           /^nova_metadata_port = 8775$/].each do |line|
            expect(chef_run).to render_file(file.name).with_content(line)
          end
        end

        it 'sets the metadata_proxy_shared_secret attribute' do
          node.set['openstack']['network']['metadata']['secret_name'] = 'network_metadata_secret'
          allow_any_instance_of(Chef::Recipe).to receive(:get_password)
            .with('token', 'network_metadata_secret')
            .and_return('network_metadata_secret_value')
          expect(chef_run).to render_file(file.name).with_content(/^metadata_proxy_shared_secret = network_metadata_secret_value$/)
        end

        it 'sets the metadata_workers attribute' do
          node.set['openstack']['network']['metadata']['metadata_workers'] = 4
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^metadata_workers = 4$/)
        end
      end

      it 'notifies the metadata agent service' do
        expect(file).to notify('service[neutron-metadata-agent]').to(:restart).immediately
      end
    end
  end
end
