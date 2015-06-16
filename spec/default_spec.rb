# Encoding: utf-8
require_relative 'spec_helper'

shared_examples 'core plugin common configurator' do |plugin_name, file_name, attrs|
  describe "#{plugin_name} config file" do
    let(:cfg_file) { chef_run.template("/etc/neutron/plugins/#{plugin_name}/#{file_name}") }

    before do
      node.set['openstack']['network']['core_plugin'] = plugin_name
    end

    it 'creates the file' do
      expect(chef_run).to create_template(cfg_file.name).with(
        user: 'neutron',
        group: 'neutron',
        mode: 0644
      )
    end

    context 'template contents' do
      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { cfg_file.name }
      end

      attrs.each do |attr, default_value|
        it "sets the default #{attr} value" do
          expect(chef_run).to render_file(cfg_file.name).with_content(/^#{attr} = #{default_value}$/)
        end

        it "sets the #{attr} attribute" do
          node.set['openstack']['network'][plugin_name][attr] = "#{attr}_value"
          expect(chef_run).to render_file(cfg_file.name).with_content(/^#{attr} = #{attr}_value$/)
        end
      end
    end
  end
end

describe 'openstack-network' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'includes openstack-identity::client' do
      expect(chef_run).to include_recipe('openstack-identity::client')
    end

    context 'plugins' do
      before do
        PLUGIN_MAP.each do |key, _value|
          node.set['openstack']['network']['core_plugin_map'][key] = key
        end
      end

      it_behaves_like 'core plugin common configurator',
                      'bigswitch',
                      PLUGIN_MAP['bigswitch'],
                      servers: 'localhost:8080'

      it_behaves_like 'core plugin common configurator',
                      'brocade',
                      PLUGIN_MAP['brocade'],
                      physical_interface_mappings: ''

      describe 'ml2' do
        let(:file) { chef_run.template('/etc/neutron/plugins/ml2/ml2_conf.ini') }

        it_behaves_like 'core plugin common configurator',
                        'ml2',
                        PLUGIN_MAP['ml2'],
                        type_drivers: 'local,flat,vlan,gre,vxlan',
                        tenant_network_types: 'local',
                        mechanism_drivers: 'openvswitch',
                        flat_networks: '',
                        network_vlan_ranges: '',
                        tunnel_id_ranges: '',
                        vni_ranges: '',
                        vxlan_group: '',
                        enable_security_group: 'True',
                        enable_ipset: 'True'

        it 'sets related attributes for openvswitch section' do
          [
            /^tenant_network_type = local$/,
            /^enable_tunneling = False$/,
            /^tunnel_type = $/,
            /^integration_bridge = br-int$/,
            /^tunnel_bridge = br-tun$/,
            /^local_ip = 127.0.0.1$/
          ].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('OVS', line)
          end
        end

        it 'sets related attributes for agent section' do
          [
            /^polling_interval = 2$/,
            /^tunnel_types = $/,
            /^veth_mtu = 1500$/,
            /^l2_population = False$/,
            /^enable_distributed_routing = False$/
          ].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('agent', line)
          end
        end

        it 'sets related attributes for securitygroup section' do
          [
            /^firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver$/,
            /^enable_security_group = True$/
          ].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('securitygroup', line)
          end
        end
      end

      describe 'cisco' do
        let(:nexus_switch_value) do
          {
            'ip0' => { 'hosts' => ['host_info00', 'host_info01'],
                       'ssh_port' => 'ssh_port0',
                       'username' => 'username0',
                       'password' => 'password0' },
            'ip1' => { 'hosts' => ['host_info10', 'host_info11'],
                       'ssh_port' => 'ssh_port1',
                       'username' => 'username1',
                       'password' => 'password1' }
          }
        end
        let(:file) { chef_run.template('/etc/neutron/plugins/cisco/cisco_plugins.ini') }

        before do
          node.set['openstack']['network']['cisco']['nexus_switch'] = nexus_switch_value
          node.set['openstack']['network']['core_plugin'] = 'cisco'
        end

        it_behaves_like 'core plugin common configurator',
                        'cisco',
                        PLUGIN_MAP['cisco'],
                        nexus_plugin: 'neutron.plugins.cisco.nexus.cisco_nexus_plugin_v2.NexusPlugin',
                        vswitch_plugin: 'neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2',
                        vlan_start: '100',
                        vlan_end: '3000',
                        vlan_name_prefix: 'q-',
                        max_ports: '100',
                        max_port_profiles: '65568',
                        max_networks: '65568',
                        model_class: 'neutron.plugins.cisco.models.virt_phy_sw_v2.VirtualPhysicalSwitchModelV2',
                        manager_class: 'neutron.plugins.cisco.segmentation.l2network_vlan_mgr_v2.L2NetworkVLANMgr',
                        nexus_driver: 'neutron.plugins.cisco.tests.unit.v2.nexus.fake_nexus_driver.CiscoNEXUSFakeDriver'

        context 'nexus_switch' do
          it 'shows the ip' do
            nexus_switch_value.each do |ip, _info|
              expect(chef_run).to render_file(file.name).with_content(/^\[NEXUS_SWITCH:#{ip}\]$/)
            end
          end

          it 'shows the host_info' do
            nexus_switch_value.each do |_ip, info|
              info['hosts'].each do |host_info|
                expect(chef_run).to render_file(file.name).with_content(/^#{host_info[0]} = #{host_info[1]}$/)
              end
            end
          end

          %w(ssh_port username password).each do |attr|
            it "shows the #{attr}" do
              nexus_switch_value.each do |_ip, info|
                expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{info[attr]}$/)
              end
            end
          end
        end
      end

      it_behaves_like 'core plugin common configurator',
                      'hyperv',
                      PLUGIN_MAP['hyperv'],
                      tenant_network_type: 'local',
                      network_vlan_ranges: '',
                      polling_interval: '2',
                      physical_network_vswitch_mappings: '\*\:external',
                      firewall_driver: 'neutron.plugins.hyperv.agent.security_groups_driver.HyperVSecurityGroupsDriver'

      describe 'linuxbridge' do
        let(:file) { chef_run.template('/etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini') }

        before do
          node.set['openstack']['network']['core_plugin'] = 'linuxbridge'
        end

        it_behaves_like 'core plugin common configurator',
                        'linuxbridge',
                        PLUGIN_MAP['linuxbridge'],
                        tenant_network_type: 'local',
                        network_vlan_ranges: '',
                        physical_interface_mappings: '',
                        enable_vxlan: 'false',
                        ttl: '',
                        tos: '',
                        vxlan_group: '224.0.0.1',
                        l2_population: 'false',
                        polling_interval: '2',
                        rpc_support_old_agents: 'false',
                        firewall_driver: 'neutron.agent.firewall.NoopFirewallDriver',
                        enable_security_group: 'True'

        it 'sets the local_ip' do
          expect(chef_run).to render_file(file.name).with_content(/^local_ip = 127.0.0.1$/)
        end
      end

      it_behaves_like 'core plugin common configurator',
                      'metaplugin',
                      PLUGIN_MAP['metaplugin'],
                      plugin_list: 'openvswitch:neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2,linuxbridge:neutron.plugins.linuxbridge.lb_neutron_plugin.LinuxBridgePluginV2',
                      l3_plugin_list: 'openvswitch:neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2,linuxbridge:neutron.plugins.linuxbridge.lb_neutron_plugin.LinuxBridgePluginV2',
                      default_flavor: 'openvswitch',
                      default_l3_flavor: 'openvswitch'

      it_behaves_like 'core plugin common configurator',
                      'midonet',
                      PLUGIN_MAP['midonet'],
                      midonet_uri: 'http://localhost:8080/midonet-api',
                      username: 'admin',
                      password: 'passw0rd',
                      project_id: '77777777-7777-7777-7777-777777777777',
                      provider_router_id: '00112233-0011-0011-0011-001122334455',
                      metadata_router_id: 'ffeeddcc-ffee-ffee-ffee-ffeeddccbbaa'

      describe 'nec' do
        let(:file) { chef_run.template('/etc/neutron/plugins/nec/nec.ini') }

        before do
          node.set['openstack']['network']['core_plugin'] = 'nec'
        end

        it_behaves_like 'core plugin common configurator',
                        'nec',
                        PLUGIN_MAP['nec'],
                        integration_bridge: 'br-int',
                        polling_interval: '2',
                        firewall_driver: 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver'

        context 'OpenFlow Controller settings' do
          { host: '127.0.0.1',  port: '8888', driver: 'trema', enable_packet_filter: 'true' }.each do |attr, value|
            it "sets the default #{attr} ofc value" do
              expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{value}$/)
            end

            it "sets the #{attr} ofc attribute" do
              node.set['openstack']['network']['nec']["ofc_#{attr}"] = "ofc_#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^#{attr} = ofc_#{attr}_value$/)
            end
          end
        end
      end

      describe 'nicira' do
        let(:file) { chef_run.template('/etc/neutron/plugins/nicira/nvp.ini') }

        before do
          node.set['openstack']['network']['core_plugin'] = 'nicira'
        end

        it_behaves_like 'core plugin common configurator',
                        'nicira',
                        PLUGIN_MAP['nicira'],
                        nvp_user: 'admin',
                        nvp_password: 'admin',
                        req_timeout: '30',
                        http_timeout: '10',
                        retries: '2',
                        redirects: '2',
                        nvp_controllers: 'xx.yy.zz.ww:443, aa.bb.cc.dd, ee.ff.gg.hh.ee:80',
                        default_tz_uuid: '1e8e52cf-fa7f-46b0-a14a-f99835a9cb53',
                        nvp_cluster_uuid: '615be8e4-82e9-4fd2-b4b3-fd141e51a5a7',
                        default_iface_name: 'breth0',
                        quota_network_gateway: '5',
                        max_lp_per_bridged_ls: '64',
                        max_lp_per_overlay_ls: '256',
                        concurrent_connections: '3',
                        metadata_mode: 'access_network'

        %w(l3 l2).each do |attr|
          it "sets the default #{attr} default gateway attribute" do
            expect(chef_run).to render_file(file.name).with_content(/^default_#{attr}_gw_service_uuid = $/)
          end

          it "sets the #{attr} default gateway attribute" do
            node.set['openstack']['network']['nicira']["default_#{attr}_gateway_service_uuid"] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^default_#{attr}_gw_service_uuid = #{attr}_value$/)
          end
        end
      end

      describe 'openvswitch' do
        let(:file) { chef_run.template('/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini') }

        before do
          node.set['openstack']['network']['core_plugin'] = 'openvswitch'
        end

        before do
          node.set['openstack']['network']['core_plugin'] = 'openvswitch'
        end

        it_behaves_like 'core plugin common configurator',
                        'openvswitch',
                        PLUGIN_MAP['openvswitch'],
                        tenant_network_type: 'local',
                        enable_tunneling: 'False',
                        polling_interval: '2',
                        veth_mtu: '1500',
                        enable_security_group: 'True'

        {
          network_vlan_ranges: '',
          tunnel_id_ranges: '',
          integration_bridge: 'br-int',
          tunnel_bridge: 'br-tun',
          int_peer_patch_port: '',
          tun_peer_patch_port: '',
          bridge_mappings: ''
        }.each do |attr, value|
          it "sets the default #{attr} when present" do
            if value.present?
              expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{value}$/)
            end
          end

          it "sets the #{attr} when present" do
            node.set['openstack']['network']['openvswitch'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
          end

          it "does not show the #{attr} when not present" do
            node.set['openstack']['network']['openvswitch'][attr] = nil
            expect(chef_run).not_to render_file(file.name).with_content(/^#{attr} = $/)
          end
        end

        it 'sets the local_ip' do
          expect(chef_run).to render_file(file.name).with_content(/^local_ip = 127.0.0.1$/)
        end

        it 'sets the default firewall_driver attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver$/)
        end

        it 'sets the firewall_driver attribute' do
          node.set['openstack']['network']['openvswitch']['fw_driver'] = 'fw_driver_value'
          expect(chef_run).to render_file(file.name).with_content(/^firewall_driver = fw_driver_value$/)
        end

        it 'sets related attributes for distributed routers' do
          node.set['openstack']['network']['l3']['router_distributed'] = true
          [
            /^enable_distributed_routing = True$/,
            /^l2_population = True$/,
            /^tunnel_types = gre, vxlan$/
          ].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('agent', line)
          end
        end
      end

      it_behaves_like 'core plugin common configurator',
                      'plumgrid',
                      PLUGIN_MAP['plumgrid'],
                      nos_server: '127.0.0.1',
                      nos_server_port: '<nos-port>',
                      username: '<nos-admin-username>',
                      password: '<nos-admin-password>',
                      servertimeout: '5',
                      topologyname: '<nos-topology-name>'

      it_behaves_like 'core plugin common configurator',
                      'ryu',
                      PLUGIN_MAP['ryu'],
                      integration_bridge: 'br-int',
                      openflow_rest_api: '127.0.0.1:8080',
                      tunnel_key_min: '1',
                      tunnel_key_max: '0xffffff',
                      tunnel_ip: '',
                      tunnel_interface: 'eth0',
                      ovsdb_port: '6634',
                      ovsdb_ip: '',
                      ovsdb_interface: 'eth0',
                      firewall_driver: 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
                      polling_interval: '2'
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

      it 'sends a notification to the service' do
        allow_any_instance_of(Chef::Recipe).to receive(:role_included?).with('os-network-server').and_return(true)
        expect(file).to notify('service[neutron-server]').to(:restart).delayed
      end

      it 'not sends a notification to the service' do
        allow_any_instance_of(Chef::Recipe).to receive(:role_included?).with('os-network-server').and_return(false)
        expect(file).not_to notify('service[neutron-server]').to(:restart).delayed
      end

      context 'template contents' do
        it_behaves_like 'custom template banner displayer' do
          let(:file_name) { file.name }
        end

        %w(debug verbose state_path log_dir auth_strategy
           dhcp_lease_duration rpc_thread_pool_size rpc_conn_pool_size
           rpc_response_timeout control_exchange allow_overlapping_ips
           notification_driver api_workers rpc_workers).each do |attr|
          it "sets the #{attr} common attribute" do
            node.set['openstack']['network'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
          end
        end

        it 'sets the lock_path attribute' do
          node.set['openstack']['network']['lock_path'] = 'lock_path_value'
          expect(chef_run).to render_config_file(file.name).with_section_content('oslo_concurrency', /^lock_path = lock_path_value$/)
        end

        it 'sets the log_config attribute if using syslog' do
          node.set['openstack']['network']['syslog']['use'] = true
          expect(chef_run).to render_file(file.name).with_content(%r{^log_config = /etc/openstack/logging.conf$})
        end

        it 'does not set the log config attribute if not using syslog' do
          node.set['openstack']['network']['syslog']['use'] = false
          expect(chef_run).not_to render_file(file.name).with_content(%r{^log_config = /etc/openstack/logging.conf$})
        end

        it 'set the router_distributed attribute for network node' do
          node.set['openstack']['network']['l3']['router_distributed'] = true
          allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-network::server').and_return(true)
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^router_distributed = True$/)
        end

        it 'set the router_distributed attribute for compute node' do
          node.set['openstack']['network']['l3']['router_distributed'] = true
          allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-network::server').and_return(false)
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^router_distributed = False$/)
        end

        it 'sets port and host attributes' do
          [
            /^bind_port = 9696$/,
            /^bind_host = 127.0.0.1$/
          ].each do |line|
            expect(chef_run).to render_config_file(file.name)\
              .with_section_content('DEFAULT', line)
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

          %w(durable_queues auto_delete).each do |attr|
            it "sets the ampq queue #{attr} attribute" do
              node.set['openstack']['mq']['network'][attr] = "#{attr}_value"
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^amqp_#{attr}=#{attr}_value$/)
            end
          end

          it 'has default heartbeat options set' do
            [/^heartbeat_timeout_threshold=0$/,
             /^heartbeat_rate=2$/].each do |line|
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', line)
            end
          end

          it 'sets the rabbit_userid attribute' do
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_userid=#{userid}$/)
          end

          it 'sets the rabbit_password attribute' do
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_password=#{password}$/)
          end

          it 'sets the rabbit_virtual_host attribute' do
            node.set['openstack']['mq']['network']['rabbit']['vhost'] = 'rabbit_virtual_host_value'
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_virtual_host=rabbit_virtual_host_value$/)
          end

          it 'sets the rabbit_retry_interval' do
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_retry_interval=1$/)
          end

          it 'sets the rabbit_max_retries' do
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_max_retries=0$/)
          end

          context 'rabbit ha enabled' do
            before do
              node.set['openstack']['mq']['network']['rabbit']['ha'] = true
            end

            it 'sets the rabbit_hosts attribute' do
              allow_any_instance_of(Chef::Recipe).to receive(:rabbit_servers)
                .and_return('rabbit_servers_value')
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_hosts=rabbit_servers_value$/)
            end

            it 'sets the rabbit_ha_queues attribute' do
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_ha_queues=True$/)
            end
          end

          context 'rabbit ha disabled' do
            before do
              node.set['openstack']['mq']['network']['rabbit']['ha'] = false
            end

            %w(host port).each do |attr|
              it "sets the non-ha rabbit_#{attr} attribute" do
                node.set['openstack']['mq']['network']['rabbit'][attr] = "rabbit_#{attr}_value"
                expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', /^rabbit_#{attr}=rabbit_#{attr}_value$/)
              end
            end
          end

          it 'does not have ssl config set' do
            [/^rabbit_use_ssl=/,
             /^kombu_ssl_version=/,
             /^kombu_ssl_keyfile=/,
             /^kombu_ssl_certfile=/,
             /^kombu_ssl_ca_certs=/,
             /^kombu_reconnect_delay=/,
             /^kombu_reconnect_timeout=/].each do |line|
              expect(chef_run).not_to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', line)
            end
          end

          it 'sets ssl config' do
            node.set['openstack']['mq']['network']['rabbit']['use_ssl'] = true
            node.set['openstack']['mq']['network']['rabbit']['kombu_ssl_version'] = 'TLSv1.2'
            node.set['openstack']['mq']['network']['rabbit']['kombu_ssl_keyfile'] = 'keyfile'
            node.set['openstack']['mq']['network']['rabbit']['kombu_ssl_certfile'] = 'certfile'
            node.set['openstack']['mq']['network']['rabbit']['kombu_ssl_ca_certs'] = 'certsfile'
            node.set['openstack']['mq']['network']['rabbit']['kombu_reconnect_delay'] = 123.123
            node.set['openstack']['mq']['network']['rabbit']['kombu_reconnect_timeout'] = 123
            [/^rabbit_use_ssl=true/,
             /^kombu_ssl_version=TLSv1.2$/,
             /^kombu_ssl_keyfile=keyfile$/,
             /^kombu_ssl_certfile=certfile$/,
             /^kombu_ssl_ca_certs=certsfile$/,
             /^kombu_reconnect_delay=123.123$/,
             /^kombu_reconnect_timeout=123$/].each do |line|
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_rabbit', line)
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

          %w(durable_queues auto_delete).each do |attr|
            it "sets the ampq queue #{attr} attribute" do
              node.set['openstack']['mq']['network'][attr] = "#{attr}_value"
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_qpid', /^amqp_#{attr}=#{attr}_value$/)
            end
          end

          %w(port username sasl_mechanisms reconnect reconnect_timeout reconnect_limit
             reconnect_interval_min reconnect_interval_max reconnect_interval heartbeat
             protocol tcp_nodelay topology_version).each do |attr|
            it "sets the common qpid #{attr} attribute" do
              node.set['openstack']['mq']['network']['qpid'][attr] = "qpid_#{attr}_value"
              expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_qpid', /^qpid_#{attr}=qpid_#{attr}_value$/)
            end
          end

          it 'sets the qpid_hostname attribute' do
            node.set['openstack']['mq']['network']['qpid']['host'] = 'qpid_hostname_value'
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_qpid', /^qpid_hostname=qpid_hostname_value$/)
          end

          it 'sets the qpid_password attribute' do
            node.set['openstack']['mq']['network']['qpid']['username'] = 'qpid_username_value'
            expect(chef_run).to render_config_file(file.name).with_section_content('oslo_messaging_qpid', /^qpid_password=qpid_password_value$/)
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

        it 'sets the dhcp_agents_per_network attribute' do
          node.set['openstack']['network']['dhcp']['dhcp_agents_per_network'] = 'dhcp_agents_per_network_value'
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^dhcp_agents_per_network = dhcp_agents_per_network_value$/)
        end

        %w(l3_ha max_l3_agents_per_router).each do |attr|
          it "sets the #{attr} attribute" do
            node.set['openstack']['network']['l3']['ha'][attr] = "#{attr}_value"
            expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^#{attr} = #{attr}_value$/)
          end
        end

        %w(notify_nova_on_port_status_changes notify_nova_on_port_data_changes send_events_interval).each do |attr|
          it "sets the #{attr} nova attribute" do
            node.set['openstack']['network']['nova'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
          end
        end

        it 'has default nova auth_plugin attribute' do
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', /^auth_plugin = v2password/)
        end

        it 'does not set the sets admin_tenant_id' do
          expect(chef_run).not_to render_config_file(file.name).with_section_content('nova', /^admin_tenant_id =/)
        end

        it 'sets the nova admin_tenant_id' do
          node.set['openstack']['network']['nova']['admin_tenant_id'] = 'admin_tenant_id_value'

          expect(chef_run).to render_config_file(file.name).with_section_content('nova', /^admin_tenant_id = admin_tenant_id_value/)
        end

        it 'has default nova user and project attributes' do
          [
            /^username = nova$/,
            /^user_domain_id = default$/,
            /^tenant_name = service$/,
            /^project_name = service$/,
            /^project_domain_id = default$/
          ].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('nova', line)
          end
        end

        it 'sets the nova region_name attribute' do
          node.set['openstack']['network']['nova']['region_name'] = 'nova_region_name_value'
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', /^region_name = nova_region_name_value$/)
        end

        it 'sets the nova password attribute' do
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', /^password = nova-pass$/)
        end

        it 'sets the nova auth_url attribute when auth_plugin is password' do
          node.set['openstack']['network']['nova']['auth_plugin'] = 'password'
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', %r{^auth_url = http://127.0.0.1:35357/$})
        end

        it 'sets the nova auth_url attribute when auth_plugin is v2password by default' do
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', %r{^auth_url = http://127.0.0.1:35357/v2.0$})
        end

        it 'sets the nova auth_url attribute when auth_plugin is v3password' do
          node.set['openstack']['network']['nova']['auth_plugin'] = 'v3password'
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', %r{^auth_url = http://127.0.0.1:35357/v3$})
        end

        it 'has default nova api insecure' do
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', /^insecure = false$/)
        end

        it 'sets nova api insecure' do
          node.set['openstack']['network']['nova']['insecure'] = true
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', /^insecure = true$/)
        end

        it 'has no nova ca certificates file set by default' do
          expect(chef_run).not_to render_config_file(file.name).with_section_content('nova', /^cafile =/)
        end

        it 'sets nova_ca_certificates_file' do
          node.set['openstack']['network']['nova']['cafile'] = 'dir/to/path'
          expect(chef_run).to render_config_file(file.name).with_section_content('nova', %r{^cafile = dir/to/path$})
        end

        it 'sets the misc_neutron values' do
          misc_neutron = %w(misc1 misc2)
          node.set['openstack']['network']['misc_neutron'] = misc_neutron
          misc_neutron.each do |misc|
            expect(chef_run).to render_file(file.name).with_content(/^#{misc}$/)
          end
        end

        %w(items network subnet port security_group security_group_rule driver router floatingip).each do |attr|
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
          expect(chef_run).to render_file(file.name).with_content(%r{^root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"$})
        end

        it 'does not set the root_helper attribute if disabled' do
          node.set['openstack']['network']['use_rootwrap'] = false
          expect(chef_run).not_to render_file(file.name).with_content(%r{^root_helper = "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"$})
        end

        it 'sets the report_interval attribute' do
          node.set['openstack']['network']['api']['agent']['agent_report_interval'] = 'report_interval_value'
          expect(chef_run).to render_file(file.name).with_content(/^report_interval = report_interval_value$/)
        end

        it 'sets the auth_uri attribute' do
          expect(chef_run).to render_file(file.name).with_content(%r{^auth_uri = http://127.0.0.1:5000/v2.0$})
        end

        it 'sets the identity_uri attribute' do
          expect(chef_run).to render_file(file.name).with_content(%r{^identity_uri = http://127.0.0.1:35357/$})
        end

        it 'sets the auth_version attribute if not equal to v2.0' do
          node.set['openstack']['network']['api']['auth']['version'] = 'auth_version_value'
          expect(chef_run).to render_file(file.name).with_content(/^auth_version = auth_version_value$/)
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
          expect(chef_run).to render_file(file.name).with_content(/^auth_version = v2.0$/)
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
            expect(chef_run).to render_file(file.name).with_content(%r{^NEUTRON_PLUGIN_CONFIG=/etc/neutron/plugins/#{plugin_name}/#{plugin_cfg}$})
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
