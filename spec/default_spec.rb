require_relative 'spec_helper'

describe 'openstack-network' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    packages = %w(neutron-common python3-neutron)
    it do
      expect(chef_run).to upgrade_package(packages)
    end

    it do
      expect(chef_run).to upgrade_package('python3-mysqldb')
    end

    it do
      expect(chef_run).to_not create_cookbook_file('/usr/bin/neutron-enable-bridge-firewall.sh')
    end

    describe '/etc/neutron/rootwrap.conf' do
      it do
        expect(chef_run).to create_template('/etc/neutron/rootwrap.conf').with(
          source: 'openstack-service.conf.erb',
          cookbook: 'openstack-common',
          owner: 'neutron',
          group: 'neutron',
          mode: '644'
        )
      end
      let(:file) { chef_run.template('/etc/neutron/rootwrap.conf') }
      [
        %r{^filters_path = /etc/neutron/rootwrap\.d,/usr/share/neutron/rootwrap$},
        %r{^exec_dirs = /sbin,/usr/sbin,/bin,/usr/bin$},
        /^use_syslog = false$/,
        /^syslog_log_facility = syslog$/,
        /^syslog_log_level = ERROR$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name)
            .with_section_content('DEFAULT', line)
        end
      end
    end

    describe '/etc/neutron/neutron.conf' do
      it do
        expect(chef_run).to create_template('/etc/neutron/neutron.conf').with(
          source: 'openstack-service.conf.erb',
          cookbook: 'openstack-common',
          owner: 'neutron',
          group: 'neutron',
          mode: '640',
          sensitive: true
        )
      end
      let(:file) { chef_run.template('/etc/neutron/neutron.conf') }
      [
        %r{^log_dir = /var/log/neutron$},
        /^control_exchange = neutron$/,
        /^core_plugin = ml2$/,
        /^bind_host = 127\.0\.0\.1$/,
        /^bind_port = 9696$/,
        %r{^transport_url = rabbit://guest:mypass@127.0.0.1:5672$},
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', line)
        end
      end

      [
        %r{^root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf$},
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('agent', line)
        end
      end
      [
        /^auth_type = password$/,
        /^region_name = RegionOne$/,
        /^username = neutron$/,
        /^user_domain_name = Default/,
        /^project_domain_name = Default/,
        /^project_name = service$/,
        /^auth_version = v3$/,
        %r{^auth_url = http://127.0.0.1:5000/v3$},
        /^password = neutron-pass$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('keystone_authtoken', line)
        end
      end
      [
        /^auth_type = password$/,
        /^region_name = RegionOne$/,
        /^username = nova$/,
        /^user_domain_name = Default/,
        /^project_name = service$/,
        /^project_domain_name = Default/,
        %r{^auth_url = http://127.0.0.1:5000/v3$},
        /^password = nova-pass$/,
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', line)
        end
      end
      [
        %r{^lock_path = /var/lib/neutron/lock$},
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('oslo_concurrency', line)
        end
      end
      [
        %(connection = mysql+pymysql://neutron:neutron@127.0.0.1:3306/neutron?charset=utf8),
      ].each do |line|
        it do
          expect(chef_run).to render_config_file(file.name).with_section_content('database', line)
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
