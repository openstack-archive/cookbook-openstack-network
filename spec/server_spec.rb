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

    include_context 'neutron-stubs'

    it 'does not install neutron-server when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'
      expect(chef_run).to_not upgrade_package 'neutron-server'
    end

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

      it 'allows overriding service names' do
        node.set['openstack']['network']['platform']['neutron_server_service'] = 'my-neutron-server'

        expect(chef_run).to enable_service 'my-neutron-server'
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
          mode: 0644
        )
      end

      it 'has a correct plugin config path' do
        expect(chef_run).to render_file(file.name).with_content(
          '/etc/neutron/plugins/ml2/ml2_conf.ini')
      end
    end

    describe '/etc/neutron/plugins/ml2/ml2_conf.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/ml2/ml2_conf.ini') }

      before do
        node.set['openstack']['network']['interface_driver'] = 'neutron.agent.linux.interface.Ml2InterfaceDriver'
      end

      it 'creates ml2_conf.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      [
        /^type_drivers = local,flat,vlan,gre,vxlan$/,
        /^tenant_network_types = local$/,
        /^mechanism_drivers = openvswitch$/,
        /^flat_networks = $/,
        /^network_vlan_ranges = $/,
        /^tunnel_id_ranges = $/,
        /^vni_ranges = $/,
        /^vxlan_group = $/,
        /^enable_security_group = True$/,
        /^enable_ipset = True$/
      ].each do |content|
        it "has a #{content.source[1...-1]} line" do
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end
    end

    describe 'rootwrap.conf' do
      let(:file) { chef_run.template('/etc/neutron/rootwrap.conf') }

      it 'creates the /etc/neutron/rootwrap.conf file' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      context 'template contents' do
        it 'shows the custom banner' do
          node.set['openstack']['network']['custom_template_banner'] = 'banner'

          expect(chef_run).to render_file(file.name).with_content(/^banner$/)
        end

        it 'sets the default attributes' do
          [
            %r{^filters_path=/etc/neutron/rootwrap.d,/usr/share/neutron/rootwrap$},
            %r{^exec_dirs=/sbin,/usr/sbin,/bin,/usr/bin$},
            /^use_syslog=false$/,
            /^syslog_log_facility=syslog$/,
            /^syslog_log_level=ERROR$/
          ].each do |line|
            expect(chef_run).to render_file(file.name).with_content(line)
          end
        end
      end
    end
  end
end
