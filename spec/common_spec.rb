# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::common' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'includes openstack-identity::client' do
      expect(chef_run).to include_recipe('openstack-identity::client')
    end

    describe 'ml2_conf.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/ml2/ml2_conf.ini') }

      it 'creates ml2_conf.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end
    end

    it 'does not upgrade python-neutronclient when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('python-neutronclient')
    end

    it 'upgrades python neutronclient package' do
      expect(chef_run).to upgrade_package('python-neutronclient')
    end

    it 'upgrades python pyparsing package' do
      expect(chef_run).to upgrade_package('python-pyparsing')
    end

    it 'upgrades mysql python package' do
      expect(chef_run).to upgrade_package('python-mysqldb')
    end

    describe 'neutron.conf' do
      let(:file) { chef_run.template('/etc/neutron/neutron.conf') }

      it 'creates neutron.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end

      context 'template contents' do
        include_context 'endpoint-stubs'

        it_behaves_like 'custom template banner displayer' do
          let(:file_name) { file.name }
        end

        %w(debug verbose state_path lock_path log_dir auth_strategy
           dhcp_lease_duration rpc_thread_pool_size rpc_conn_pool_size
           rpc_response_timeout control_exchange allow_overlapping_ips
           notification_driver api_workers rpc_workers).each do |attr|
          it "sets the #{attr} common attribute" do
            node.set['openstack']['network'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
          end
        end

        it 'sets the log_config attribute if using syslog' do
          node.set['openstack']['network']['syslog']['use'] = true
          expect(chef_run).to render_file(file.name).with_content(%r(^log_config = /etc/openstack/logging.conf$))
        end

        it 'does not set the log config attribute if not using syslog' do
          node.set['openstack']['network']['syslog']['use'] = false
          expect(chef_run).not_to render_file(file.name).with_content(%r(^log_config = /etc/openstack/logging.conf$))
        end

        %w(host port).each do |attr|
          it "sets the bind #{attr} attribute" do
            expect(chef_run).to render_file(file.name).with_content(/^bind_#{attr} = network_#{attr}$/)
          end
        end

        it 'sets the core_plugin attribute' do
          core_plugin_value = PLUGIN_MAP.keys.first
          node.set['openstack']['network']['core_plugin'] = core_plugin_value
          node.set['openstack']['network']['core_plugin_map'][core_plugin_value] = core_plugin_value
          expect(chef_run).to render_file(file.name).with_content(/^core_plugin = #{core_plugin_value}$/)
        end

        it 'sets the service_plugins attribute if any present' do
          node.set['openstack']['network']['service_plugins'] = %w(service_plugin1 service_plugin2)
          expect(chef_run).to render_file(file.name).with_content(/^service_plugins = service_plugin1,service_plugin2$/)
        end

        it 'does not set the service_plugins attribute if not present' do
          node.set['openstack']['network']['service_plugins'] = []
          expect(chef_run).not_to render_file(file.name).with_content(/^service_plugins = $/)
        end

        %w(durable_queues auto_delete).each do |attr|
          it "sets the ampq queue #{attr} attribute" do
            node.set['openstack']['mq']['network'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^amqp_#{attr}=#{attr}_value$/)
          end
        end

        context 'rabbitmq service' do
          let(:userid) { 'rabbit_userid_value' }
          let(:password) { 'rabbit_password' }
          before do
            node.set['openstack']['mq']['network']['service_type'] = 'rabbitmq'
            node.set['openstack']['mq']['network']['rabbit']['userid'] = userid
            allow_any_instance_of(Chef::Recipe).to receive(:get_password)
              .with('user', userid)
              .and_return(password)
          end

          it 'sets the rabbit_userid attribute' do
            expect(chef_run).to render_file(file.name).with_content(/^rabbit_userid=#{userid}$/)
          end

          it 'sets the rabbit_password attribute' do
            expect(chef_run).to render_file(file.name).with_content(/^rabbit_password=#{password}$/)
          end

          it 'sets the rabbit_virtual_host attribute' do
            node.set['openstack']['mq']['network']['rabbit']['vhost'] = 'rabbit_virtual_host_value'
            expect(chef_run).to render_file(file.name).with_content(/^rabbit_virtual_host=rabbit_virtual_host_value$/)
          end

          context 'rabbit ha enabled' do
            before do
              node.set['openstack']['mq']['network']['rabbit']['ha'] = true
            end

            it 'sets the rabbit_hosts attribute' do
              allow_any_instance_of(Chef::Recipe).to receive(:rabbit_servers)
                .and_return('rabbit_servers_value')
              expect(chef_run).to render_file(file.name).with_content(/^rabbit_hosts=rabbit_servers_value$/)
            end

            it 'sets the rabbit_ha_queues attribute' do
              expect(chef_run).to render_file(file.name).with_content(/^rabbit_ha_queues=True$/)
            end
          end

          context 'rabbit ha disabled' do
            before do
              node.set['openstack']['mq']['network']['rabbit']['ha'] = false
            end

            %w(host port use_ssl).each do |attr|
              it "sets the non-ha rabbit_#{attr} attribute" do
                node.set['openstack']['mq']['network']['rabbit'][attr] = "rabbit_#{attr}_value"
                expect(chef_run).to render_file(file.name).with_content(/^rabbit_#{attr}=rabbit_#{attr}_value$/)
              end
            end
          end
        end

        context 'qpid service' do
          before do
            node.set['openstack']['mq']['network']['service_type'] = 'qpid'
            allow_any_instance_of(Chef::Recipe).to receive(:get_password)
              .with('user', 'qpid_username_value')
              .and_return('qpid_password_value')
          end

          %w(port username sasl_mechanisms reconnect reconnect_timeout reconnect_limit
             reconnect_interval_min reconnect_interval_max reconnect_interval heartbeat
             protocol tcp_nodelay topology_version).each do |attr|
            it "sets the common qpid #{attr} attribute" do
              node.set['openstack']['mq']['network']['qpid'][attr] = "qpid_#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^qpid_#{attr}=qpid_#{attr}_value$/)
            end
          end

          it 'sets the qpid_hostname attribute' do
            node.set['openstack']['mq']['network']['qpid']['host'] = 'qpid_hostname_value'
            expect(chef_run).to render_file(file.name).with_content(/^qpid_hostname=qpid_hostname_value$/)
          end

          it 'sets the qpid_password attribute' do
            node.set['openstack']['mq']['network']['qpid']['username'] = 'qpid_username_value'
            expect(chef_run).to render_file(file.name).with_content(/^qpid_password=qpid_password_value$/)
          end
        end

        it 'sets the notification_topics attribute' do
          node.set['openstack']['mq']['network']['notification_topics'] = 'notification_topics_value'
          expect(chef_run).to render_file(file.name).with_content(/^notification_topics = notification_topics_value$/)
        end

        it 'sets the agent_down_time attribute' do
          node.set['openstack']['network']['api']['agent']['agent_down_time'] = 'agent_down_time_value'
          expect(chef_run).to render_file(file.name).with_content(/^agent_down_time = agent_down_time_value$/)
        end

        it 'sets the network_scheduler_driver attribute' do
          node.set['openstack']['network']['dhcp']['scheduler'] = 'network_scheduler_driver_value'
          expect(chef_run).to render_file(file.name).with_content(/^network_scheduler_driver = network_scheduler_driver_value$/)
        end

        it 'sets the router_scheduler_driver attribute' do
          node.set['openstack']['network']['l3']['scheduler'] = 'router_scheduler_driver_value'
          expect(chef_run).to render_file(file.name).with_content(/^router_scheduler_driver = router_scheduler_driver_value$/)
        end

        %w(notify_nova_on_port_status_changes notify_nova_on_port_data_changes send_events_interval).each do |attr|
          it "sets the #{attr} nova attribute" do
            node.set['openstack']['network']['nova'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
          end
        end

        %w(region_name admin_username admin_tenant_id).each do |attr|
          it "sets the #{attr} nova attribute" do
            node.set['openstack']['network']['nova'][attr] = "nova_#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^nova_#{attr} = nova_#{attr}_value$/)
          end
        end

        it 'sets the nova_url attribute' do
          node.set['openstack']['network']['nova']['url_version'] = 'nova_version_value'
          allow_any_instance_of(Chef::Recipe).to receive(:uri_from_hash)
          allow_any_instance_of(Chef::Recipe).to receive(:uri_from_hash)
            .with('host' => 'compute_host', 'port' => 'compute_port', 'path' => 'nova_version_value')
            .and_return('nova_url_value')
          expect(chef_run).to render_file(file.name).with_content(/^nova_url = nova_url_value$/)
        end

        it 'sets the nova_admin_password attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^nova_admin_password = nova-pass$/)
        end

        it 'sets the nova_admin_auth_url attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^nova_admin_auth_url = identity_uri$/)
        end

        it 'sets the misc_neutron values' do
          misc_neutron = %w(misc1 misc2)
          node.set['openstack']['network']['misc_neutron'] = misc_neutron
          misc_neutron.each do |misc|
            expect(chef_run).to render_file(file.name).with_content(/^#{misc}$/)
          end
        end

        %w(items network subnet port security_group security_group_rule driver).each do |attr|
          it "sets the quota #{attr} attribute" do
            node.set['openstack']['network']['quota'][attr] = "quota_#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^quota_#{attr} = quota_#{attr}_value$/)
          end
        end

        it 'sets the default_quota attribute' do
          node.set['openstack']['network']['quota']['default'] = 'default_quota_value'
          expect(chef_run).to render_file(file.name).with_content(/^default_quota = default_quota_value$/)
        end

        it 'sets the root_helper attribute if enabled' do
          node.set['openstack']['network']['use_rootwrap'] = true
          expect(chef_run).to render_file(file.name).with_content(%r(^root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"$))
        end

        it 'does not set the root_helper attribute if disabled' do
          node.set['openstack']['network']['use_rootwrap'] = false
          expect(chef_run).not_to render_file(file.name).with_content(%r(^root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"$))
        end

        it 'sets the report_interval attribute' do
          node.set['openstack']['network']['api']['agent']['agent_report_interval'] = 'report_interval_value'
          expect(chef_run).to render_file(file.name).with_content(/^report_interval = report_interval_value$/)
        end

        it 'sets the auth_uri attribute' do
          allow_any_instance_of(Chef::Recipe).to receive(:auth_uri_transform)
            .and_return('auth_uri_value')
          expect(chef_run).to render_file(file.name).with_content(/^auth_uri = auth_uri_value$/)
        end

        %w(host port).each do |attr|
          it "sets the auth_#{attr} attribute" do
            expect(chef_run).to render_file(file.name).with_content(/^auth_#{attr} = identity_#{attr}$/)
          end
        end

        it 'sets the auth_protocol attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^auth_protocol = identity_scheme$/)
        end

        it 'sets the auth_version attribute if not equal to v2.0' do
          node.set['openstack']['network']['api']['auth']['version'] = 'auth_version_value'
          expect(chef_run).to render_file(file.name).with_content(/^auth_version = auth_version_value$/)
        end

        it 'does not set the auth_version attribute if equal to v2.0' do
          node.set['openstack']['network']['api']['auth']['version'] = 'v2.0'
          expect(chef_run).not_to render_file(file.name).with_content(/^auth_version = v2.0$/)
        end

        %w(tenant_name user).each do |attr|
          it "sets the admin_#{attr} attribute" do
            node.set['openstack']['network']["service_#{attr}"] = "admin_#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^admin_#{attr} = admin_#{attr}_value$/)
          end
        end

        it 'sets the admin_password attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^admin_password = neutron-pass$/)
        end

        it 'sets the signing_dir attribute' do
          node.set['openstack']['network']['api']['agent']['signing_dir'] = 'signing_dir_value'
          expect(chef_run).to render_file(file.name).with_content(/^signing_dir = signing_dir_value$/)
        end

        it 'uses default values for attributes' do
          expect(chef_run).not_to render_file(file.name).with_content(
            /^memcached_servers =/)
          expect(chef_run).not_to render_file(file.name).with_content(
            /^memcache_security_strategy =/)
          expect(chef_run).not_to render_file(file.name).with_content(
            /^memcache_secret_key =/)
          expect(chef_run).not_to render_file(file.name).with_content(
            /^cafile =/)
          expect(chef_run).to render_file(file.name).with_content(/^hash_algorithms = md5$/)
          expect(chef_run).to render_file(file.name).with_content(/^insecure = false$/)
        end

        it 'sets memcached server(s)' do
          node.set['openstack']['network']['api']['auth']['memcached_servers'] = 'localhost:11211'
          expect(chef_run).to render_file(file.name).with_content(/^memcached_servers = localhost:11211$/)
        end

        it 'sets memcache security strategy' do
          node.set['openstack']['network']['api']['auth']['memcache_security_strategy'] = 'MAC'
          expect(chef_run).to render_file(file.name).with_content(/^memcache_security_strategy = MAC$/)
        end

        it 'sets memcache secret key' do
          node.set['openstack']['network']['api']['auth']['memcache_secret_key'] = '0123456789ABCDEF'
          expect(chef_run).to render_file(file.name).with_content(/^memcache_secret_key = 0123456789ABCDEF$/)
        end

        it 'sets cafile' do
          node.set['openstack']['network']['api']['auth']['cafile'] = 'dir/to/path'
          expect(chef_run).to render_file(file.name).with_content(%r{^cafile = dir/to/path$})
        end

        it 'sets token hash algorithms' do
          node.set['openstack']['network']['api']['auth']['hash_algorithms'] = 'sha2'
          expect(chef_run).to render_file(file.name).with_content(/^hash_algorithms = sha2$/)
        end

        it 'sets insecure' do
          node.set['openstack']['network']['api']['auth']['insecure'] = true
          expect(chef_run).to render_file(file.name).with_content(/^insecure = true$/)
        end

        it 'sets the connection attribute' do
          node.set['openstack']['db']['network']['username'] = 'db_username_value'
          allow_any_instance_of(Chef::Recipe).to receive(:db_uri)
            .with('network', 'db_username_value', 'neutron')
            .and_return('connection_value')
          expect(chef_run).to render_file(file.name).with_content(/^connection = connection_value$/)
        end

        %w(slave_connection max_retries retry_interval min_pool_size max_pool_size idle_timeout
           max_overflow connection_debug connection_trace pool_timeout).each do |attr|
          it "sets the #{attr} attribute" do
            node.set['openstack']['db']['network'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
          end
        end

        it 'sets the service_provider attribute if present' do
          service_providers = %w(service_provider1 service_provider2)
          node.set['openstack']['network']['service_provider'] = service_providers
          service_providers.each do |service_provider_value|
            expect(chef_run).to render_file(file.name).with_content(/^service_provider = #{service_provider_value}$/)
          end
        end

        it 'does not show the service_provider key if none present' do
          node.set['openstack']['network']['service_provider'] = []
          expect(chef_run).not_to render_file(file.name).with_content(/^service_provider = /)
        end
      end
    end

    describe 'policy file' do
      it 'does not manage policy file unless specified' do
        expect(chef_run).not_to create_remote_file('/etc/neutron/policy.json')
      end
      describe 'policy file specified' do
        before { node.set['openstack']['network']['policyfile_url'] = 'http://server/mypolicy.json' }
        let(:remote_policy) { chef_run.remote_file('/etc/neutron/policy.json') }
        it 'manages policy file when remote file is specified' do
          expect(chef_run).to create_remote_file('/etc/neutron/policy.json').with(
            user: 'neutron',
            group: 'neutron',
            mode: 00644)
        end
      end
    end

    describe '/etc/default/neutron-server' do
      let(:file) { chef_run.template('/etc/default/neutron-server') }

      it 'neutron-server config file' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0644
        )
      end

      context 'template contents' do
        it_behaves_like 'custom template banner displayer' do
          let(:file_name) { file.name }
        end

        PLUGIN_MAP.each do |plugin_name, plugin_cfg|
          it "sets the path to the #{plugin_name} plugin config" do
            node.set['openstack']['network']['core_plugin'] = plugin_name
            node.set['openstack']['network']['core_plugin_map'][plugin_name] = plugin_name
            expect(chef_run).to render_file(file.name).with_content(%r(^NEUTRON_PLUGIN_CONFIG=/etc/neutron/plugins/#{plugin_cfg}$))
          end
        end
      end
    end

    describe '/etc/neutron/rootwrap.conf' do
      let(:file) { chef_run.template('/etc/neutron/rootwrap.conf') }

      it 'rootwrap config file' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0644
        )
      end

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end
    end
  end
end
