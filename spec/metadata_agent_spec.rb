require_relative 'spec_helper'

describe 'openstack-network::metadata_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it do
      expect(chef_run).to upgrade_package 'neutron-metadata-agent'
    end

    it do
      expect(chef_run).to enable_service('neutron-metadata-agent').with(
        service_name: 'neutron-metadata-agent',
        supports: {
          status: true,
          restart: true,
        }
      )
    end

    it do
      expect(chef_run).to start_service('neutron-metadata-agent')
    end

    %w(template[/etc/neutron/neutron.conf] template[/etc/neutron/metadata_agent.ini]).each do |resource|
      it do
        expect(chef_run.service('neutron-metadata-agent')).to subscribe_to(resource).delayed
      end
    end

    describe 'metadata_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/metadata_agent.ini') }

      it 'creates metadata_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          source: 'openstack-service.conf.erb',
          cookbook: 'openstack-common',
          user: 'neutron',
          group: 'neutron',
          mode: '644',
          sensitive: true
        )
      end

      context 'template contents' do
        [
          /^metadata_proxy_shared_secret = metadata-secret$/,
        ].each do |line|
          it do
            expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', line)
          end
        end
      end
    end
    it do
      expect(chef_run).to run_ruby_block('delete all attributes in '\
  "node['openstack']['network_metadata']['conf_secrets']")
    end
  end
end
