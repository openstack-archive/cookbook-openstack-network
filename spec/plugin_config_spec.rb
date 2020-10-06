require_relative 'spec_helper'

describe 'openstack-network::plugin_config' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      node.override['openstack']['network']['plugins']['ml2'].tap do |ml2|
        ml2['path'] = '/etc/neutron/more_plugins'
        ml2['filename'] = 'ml2_conf.ini'
        ml2['conf'].tap do |conf|
          conf['section']['key'] = 'value'
        end
      end
      node.override['openstack']['network']['plugins']['openvswitch'].tap do |ovs|
        ovs['path'] = '/etc/neutron/plugins/'
        ovs['filename'] = 'openvswitch_conf.ini'
        ovs['conf'].tap do |conf|
          conf['section']['key'] = 'value'
        end
      end
      runner.converge(described_recipe)
    end

    %w(/etc/neutron/more_plugins /etc/neutron/plugins/).each do |dir|
      it do
        expect(chef_run).to create_directory(dir)
          .with(
            recursive: true,
            owner: 'neutron',
            group: 'neutron',
            mode: '700'
          )
      end

      %w(ml2_conf.ini openvswitch_conf.ini).each do |conf|
        let(:file) { chef_run.template(File.join(dir, conf)) }
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('section', 'key = value')
        end
      end
    end
  end
end
