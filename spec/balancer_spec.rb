# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::balancer' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['lbaas']['enabled'] = 'True'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'subscribes the agent service to its relevant config files' do
      expect(chef_run.service('neutron-lb-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    it 'does not upgrade neutron-lbaas-agent when nova networking.' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('neutron-lbaas-agent')
    end

    ['haproxy', 'neutron-lbaas-agent'].each do |pack|
      it "upgrades #{pack} package" do
        expect(chef_run).to upgrade_package(pack)
      end
    end

    it 'enables agent service' do
      expect(chef_run).to enable_service('neutron-lb-agent')
    end

    describe 'lbaas_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/lbaas_agent.ini') }

      it 'creates lbaas_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end

      context 'template contents' do
        it_behaves_like 'custom template banner displayer' do
          let(:file_name) { file.name }
        end

        it 'displays the debug setting' do
          node.set['openstack']['network']['debug'] = 'debug_value'
          expect(chef_run).to render_file(file.name).with_content(/^debug = debug_value$/)
        end

        it 'displays the lbaas device_driver setting' do
          node.set['openstack']['network']['lbaas']['device_driver'] = 'device_driver_value'
          expect(chef_run).to render_file(file.name).with_content(/^device_driver = device_driver_value$/)
        end

        it 'displays the interface driver setting for ovs lbaas plugin' do
          node.set['openstack']['network']['lbaas_plugin'] = 'ovs'
          node.set['openstack']['network']['lbaas']['ovs_use_veth'] = 'True'
          expect(chef_run).to render_file(file.name).with_content(/^interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver$/)
          expect(chef_run).to render_file(file.name).with_content(/^ovs_use_veth = True$/)
        end

        it 'displays the interface driver setting for linuxbridge lbaas plugin' do
          node.set['openstack']['network']['lbaas_plugin'] = 'linuxbridge'
          expect(chef_run).to render_file(file.name).with_content(/^interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver$/)
        end

        it 'displays a null interface driver setting for other lbaas plugins' do
          node.set['openstack']['network']['lbaas_plugin'] = 'another_lbaas-plugin'
          node.set['openstack']['network']['lbaas']['custom_interface_driver'] = 'custom_driver'
          expect(chef_run).to render_file(file.name).with_content(/^interface_driver = custom_driver$/)
        end

        it 'displays user_group as nogroup' do
          expect(chef_run).to render_file(file.name).with_content(/^user_group = nogroup$/)
        end
      end

      it 'notifies the lb agent service' do
        expect(file).to notify('service[neutron-lb-agent]').to(:restart).delayed
      end
    end
  end
end
