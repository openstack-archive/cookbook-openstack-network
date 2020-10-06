require_relative 'spec_helper'

describe 'openstack-network::server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge('openstack-network::ml2_core_plugin', described_recipe)
    end
    include_context 'neutron-stubs'

    describe 'package and services' do
      it do
        expect(chef_run).to upgrade_package %w(neutron-server)
      end

      context 'allows overriding package names' do
        cust_pkgs = %w(my-neutron my-other-neutron)
        cached(:chef_run) do
          node.override['openstack']['network']['platform']['neutron_server_packages'] = cust_pkgs
          runner.converge('openstack-network::ml2_core_plugin', described_recipe)
        end
        it do
          expect(chef_run).to upgrade_package(cust_pkgs)
        end
      end

      it do
        expect(chef_run).to enable_service('neutron-server').with(
          service_name: 'neutron-server',
          supports: {
            status: true,
            restart: true,
          }
        )
      end

      it do
        expect(chef_run).to start_service 'neutron-server'
      end

      let(:neutron_service) { chef_run.service('neutron-server') }

      it do
        expect(neutron_service).to subscribe_to('template[/etc/neutron/neutron.conf]').on(:restart).delayed
      end

      it do
        expect(neutron_service).to_not subscribe_to('remote_file[/etc/neutron/policy.json]').on(:restart).delayed
      end

      context 'set policyfile_url' do
        cached(:chef_run) do
          node.override['openstack']['network']['policyfile_url'] = 'http://www.someurl.com'
          runner.converge('openstack-network::ml2_core_plugin', described_recipe)
        end
        it do
          expect(neutron_service).to subscribe_to('remote_file[/etc/neutron/policy.json]').on(:restart).delayed
        end
      end

      context 'allows overriding service names' do
        cached(:chef_run) do
          node.override['openstack']['network']['platform']['neutron_server_service'] = 'my-neutron-server'
          runner.converge('openstack-network::ml2_core_plugin', described_recipe)
        end
        it do
          expect(chef_run).to enable_service('neutron-server').with(
            service_name: 'my-neutron-server'
          )
        end
      end

      context 'allows overriding package options' do
        cust_opts = ['-o', 'Dpkg::Options::=--force-confold', '-o', 'Dpkg::Options::=--force-confdef', '--force-yes']
        cached(:chef_run) do
          node.override['openstack']['network']['platform']['package_overrides'] = cust_opts
          runner.converge('openstack-network::ml2_core_plugin', described_recipe)
        end
        it do
          expect(chef_run).to upgrade_package('neutron-server').with(options: cust_opts)
        end
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
          source: 'neutron-server.erb',
          user: 'root',
          group: 'root',
          mode: '644',
          variables: {
            core_plugin_config: '/etc/neutron/plugins/ml2/ml2_conf.ini',
          }
        )
      end

      it do
        expect(chef_run).to render_file(file.name).with_content(
          %r{^NEUTRON_PLUGIN_CONFIG="/etc/neutron/plugins/ml2/ml2_conf.ini"$}
        )
      end
    end
  end
end
