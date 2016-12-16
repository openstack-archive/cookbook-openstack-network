# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    %w(neutron-common python-mysqldb).each do |package|
      it do
        expect(chef_run).to upgrade_package(package)
      end
    end

    it do
      expect(chef_run).to create_directory('/var/cache/neutron')
        .with(owner: 'neutron',
              group: 'neutron',
              mode: 00700)
    end

    describe '/var/cache/neutron/api with pki set' do
      before do
        node.override['openstack']['auth']['strategy'] = 'pki'
      end
      it do
        expect(chef_run).to create_directory('/var/cache/neutron/api')
          .with(owner: 'neutron',
                group: 'neutron',
                mode: 00700)
      end
    end

    describe '/var/cache/neutron/api with pki set' do
      before do
        node.override['openstack']['auth']['strategy'] = 'not_pki'
      end
      it do
        expect(chef_run).not_to create_directory('/var/cache/neutron/api')
          .with(owner: 'neutron',
                group: 'neutron',
                mode: 00700)
      end
    end

    describe '/etc/neutron/rootwrap.conf' do
      let(:file) { chef_run.template('/etc/neutron/rootwrap.conf') }
      [
        %r{^filters_path = /etc/neutron/rootwrap\.d,/usr/share/neutron/rootwrap$},
        %r{^exec_dirs = /sbin,/usr/sbin,/bin,/usr/bin$},
        /^use_syslog = false$/,
        /^syslog_log_facility = syslog$/,
        /^syslog_log_level = ERROR$/
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('DEFAULT', line)
        end
      end
    end

    describe '/etc/neutron/neutron.conf' do
      let(:file) { chef_run.template('/etc/neutron/neutron.conf') }
      [
        %r{^log_dir = /var/log/neutron$},
        /^control_exchange = neutron$/,
        /^core_plugin = ml2$/,
        %r{^transport_url = rabbit://guest:mypass@127.0.0.1:5672$},
        /^bind_host = 127\.0\.0\.1$/,
        /^bind_port = 9696$/
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('DEFAULT', line)
        end
      end
      [
        %r{^root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf$}
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('agent', line)
        end
      end
      [
        /^project_name = service$/,
        /^username = neutron$/,
        /^user_domain_name = Default/,
        /^project_domain_name = Default/,
        %r{^auth_url = http://127\.0\.0\.1:5000/v3$},
        /^password = neutron-pass$/,
        /^auth_type = v3password$/
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('keystone_authtoken', line)
        end
      end
      [
        /^region_name = RegionOne$/,
        /^auth_type = v3password$/,
        %r{^auth_url = http://127\.0\.0\.1:5000/v3$},
        /^username = nova$/,
        /^user_domain_name = Default/,
        /^project_domain_name = Default/,
        /^project_name = service$/
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('nova', line)
        end
      end
      [
        %r{^connection = mysql://neutron:neutron@127\.0\.0\.1:3306/neutron\?charset=utf8$}
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('database', line)
        end
      end
    end
    it do
      allow(chef_run).to receive(:"node['openstack']['network']['conf_secrets']").and_return(nil)
    end
    it do
      expect(chef_run).to run_ruby_block("delete all attributes in node['openstack']['network']['conf_secrets']")
    end
  end
end
