# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do

  describe 'ubuntu' do
    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.BridgeInterfaceDriver'
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
        n.set['openstack']['db']['network']['db_name'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::linuxbridge'
    end

    it 'does not install linuxbridge agent package when nova networking' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      chef_run.converge 'openstack-network::linuxbridge'
      expect(chef_run).to_not install_package 'neutron-plugin-linuxbridge-agent'
    end

    it 'installs linuxbridge agent' do
      expect(@chef_run).to install_package 'neutron-plugin-linuxbridge-agent'
    end

    it 'sets the linuxbridge service to start on boot' do
      expect(@chef_run).to enable_service 'neutron-plugin-linuxbridge-agent'
    end

    describe '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini' do
      before do
        @file = @chef_run.template(
          '/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini')
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'has a correct sql_connection value' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'mysql://neutron:neutron@127.0.0.1:3306/neutron')
      end

      it 'sets sqlalchemy attributes' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'sql_dbpool_enable = False')
        expect(@chef_run).to render_file(@file.name).with_content(
          'sql_min_pool_size = 1')
        expect(@chef_run).to render_file(@file.name).with_content(
          'sql_max_pool_size = 5')
        expect(@chef_run).to render_file(@file.name).with_content(
          'sql_idle_timeout = 3600')
      end
    end
  end
end
