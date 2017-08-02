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

    it 'upgrades neutron metadata agent' do
      expect(chef_run).to upgrade_package 'neutron-metadata-agent'
    end
    it do
      expect(chef_run).to enable_service('neutron-metadata-agent')
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
          mode: 0o644
        )
      end

      context 'template contents' do
        it 'sets the metadata_proxy_shared_secret attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^metadata_proxy_shared_secret = metadata-secret$/)
        end
      end

      it 'notifies the metadata agent service' do
        expect(file).to notify('service[neutron-metadata-agent]').to(:restart).delayed
      end
    end
    it do
      expect(chef_run).to run_ruby_block('delete all attributes in '\
  "node['openstack']['network_metadata']['conf_secrets']")
    end
  end
end
