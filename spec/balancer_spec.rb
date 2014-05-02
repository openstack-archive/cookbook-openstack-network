# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::balancer' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

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

      it 'has default settings' do
        expect(chef_run).to render_file(file.name).with_content(/periodic_interval = 10/)
        expect(chef_run).to render_file(file.name).with_content(
          /interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/)
        expect(chef_run).to render_file(file.name).with_content(
          /device_driver = neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver/)
      end

      it 'has configurable device_driver setting' do
        node.set['openstack']['network']['lbaas']['device_driver'] = 'SomeRandomDriver'

        expect(chef_run).to render_file(file.name).with_content(
          /device_driver = SomeRandomDriver/)
      end

      it 'notifies the lb agent service' do
        expect(file).to notify('service[neutron-lb-agent]').to(:restart).delayed
      end
    end

  end

end
