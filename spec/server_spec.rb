# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end
    before do
      node.set['openstack']['network']['plugins']['ml2']['path'] = '/etc/neutron/plugins/ml2'
      node.set['openstack']['network']['plugins']['ml2']['filename'] = 'ml2_conf.ini'
    end
    include_context 'neutron-stubs'

    describe 'package and services' do
      it 'upgrades neutron-server packages' do
        expect(chef_run).to upgrade_package 'neutron-server'
      end

      it 'allows overriding package names' do
        cust_pkgs = ['my-neutron', 'my-other-neutron']
        node.set['openstack']['network']['platform']['neutron_server_packages'] = cust_pkgs

        cust_pkgs.each do |pkg|
          expect(chef_run).to upgrade_package(pkg)
        end
      end

      it 'sets the neutron server service to start on boot' do
        expect(chef_run).to enable_service 'neutron-server'
      end

      it 'starts the neutron server service' do
        expect(chef_run).to start_service 'neutron-server'
      end

      let(:neutron_service) { chef_run.service('neutron-server') }

      it do
        expect(neutron_service)
          .to subscribe_to('template[/etc/neutron/neutron.conf]').on(:restart).delayed
      end

      it do
        node.set['openstack']['network']['policyfile_url'] = 'http://www.someurl.com'
        expect(neutron_service)
          .to subscribe_to('remote_file[/etc/neutron/policy.json]').on(:restart).delayed
      end

      it 'allows overriding service names' do
        node.set['openstack']['network']['platform']['neutron_server_service'] = 'my-neutron-server'

        expect(chef_run).to enable_service('neutron-server').with(
          service_name: 'my-neutron-server'
        )
      end

      it 'allows overriding package options' do
        cust_opts = "-o Dpkg::Options::='--force-confold' -o Dpkg::Options::='--force-confdef' --force-yes"
        node.set['openstack']['network']['platform']['package_overrides'] = cust_opts

        expect(chef_run).to upgrade_package('neutron-server').with(options: cust_opts)
      end

      it 'does not upgrade openvswitch package or the agent' do
        expect(chef_run).not_to upgrade_package 'openvswitch'
        expect(chef_run).not_to upgrade_package 'neutron-plugin-openvswitch-agent'
        expect(chef_run).not_to enable_service 'neutron-plugin-openvswitch-agent'
      end
    end

    describe '/etc/default/neutron-server' do
      let(:file) { chef_run.template('/etc/default/neutron-server') }

      it 'creates /etc/default/neutron-server' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0o644
        )
      end
    end

    describe 'rootwrap.conf' do
      let(:file) { chef_run.template('/etc/neutron/rootwrap.conf') }

      it 'creates the /etc/neutron/rootwrap.conf file' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0o644
        )
      end

      context 'template contents' do
        it 'sets the default attributes' do
          [
            %r{^filters_path = /etc/neutron/rootwrap.d,/usr/share/neutron/rootwrap$},
            %r{^exec_dirs = /sbin,/usr/sbin,/bin,/usr/bin$},
            /^use_syslog = false$/,
            /^syslog_log_facility = syslog$/,
            /^syslog_log_level = ERROR$/
          ].each do |line|
            expect(chef_run).to render_file(file.name).with_content(line)
          end
        end
      end
    end
  end
end
