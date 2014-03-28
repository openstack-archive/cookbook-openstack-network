# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::metadata_agent' do

  describe 'ubuntu' do

    before do
      neutron_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS do |n|
        n.set['openstack']['compute']['network']['service_type'] = 'neutron'
      end
      @chef_run.converge 'openstack-network::metadata_agent'
    end

    it 'does not install quamtum metadata agent when nova networking' do
      chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      node = chef_run.node
      node.set['openstack']['compute']['network']['service_type'] = 'nova'
      chef_run.converge 'openstack-network::metadata_agent'
      expect(chef_run).to_not install_package 'neutron-metadata-agent'
    end

    it 'installs quamtum metadata agent' do
      expect(@chef_run).to install_package 'neutron-metadata-agent'
    end

    it 'subscribes the metadata agent service to neutron.conf' do
      expect(@chef_run.service('neutron-metadata-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    describe 'metadata_agent.ini' do

      before do
        @file = @chef_run.template '/etc/neutron/metadata_agent.ini'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('neutron')
        expect(@file.group).to eq('neutron')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'sets auth url correctly' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'auth_url = http://127.0.0.1:5000/v2.0')
      end
      it 'sets auth region correctly' do
        @chef_run.node.set['openstack']['network']['region'] = 'testRegion'
        expect(@chef_run).to render_file(@file.name).with_content(
          'auth_region = testRegion')
      end
      it 'sets admin tenant name' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'admin_tenant_name = service')
      end
      it 'sets admin user' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'admin_user = neutron')
      end
      it 'sets admin password' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'admin_password = neutron-pass')
      end
      it 'sets nova metadata ip correctly' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'nova_metadata_ip = 127.0.0.1')
      end
      it 'sets nova metadata ip correctly' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'nova_metadata_port = 8775')
      end
      it 'sets neutron secret correctly' do
        expect(@chef_run).to render_file(@file.name).with_content(
          'metadata_proxy_shared_secret = metadata-secret')
      end

      it 'notifies the metadata agent service' do
        expect(@file).to notify('service[neutron-metadata-agent]').to(:restart).immediately
      end
    end
  end
end
