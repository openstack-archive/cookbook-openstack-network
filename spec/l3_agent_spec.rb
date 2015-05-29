# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      node.set['openstack']['network']['l3']['external_network_bridge_interface'] = 'eth1'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'starts the l3 agent on boot' do
      expect(chef_run).to enable_service('neutron-l3-agent')
    end

    it 'subscribes the l3 agent service to neutron.conf' do
      expect(chef_run.service('neutron-l3-agent')).to subscribe_to('template[/etc/neutron/neutron.conf]').delayed
    end

    it 'does not install neutron l3 package when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not upgrade_package('neutron-l3-agent')
    end

    ['neutron-l3-agent', 'radvd', 'keepalived'].each do |pack|
      it "upgrades #{pack} package" do
        expect(chef_run).to upgrade_package(pack)
      end
    end

    describe 'gateway_external_network_id' do
      before do
        node.set['openstack']['network']['l3']['gateway_external_network_name'] = 'public'
      end

      it 'looks up and sets the id attribute if needed' do
        node.set['openstack']['network']['l3']['gateway_external_network_id'] = nil
        chef_run.ruby_block('query gateway external network uuid').old_run_action(:create)
        expect(chef_run.node['openstack']['network']['l3']['gateway_external_network_id']).to eq '000-NET-UUID-FROM-CLI'
      end

      it 'uses the id attribute if it is already set' do
        node.set['openstack']['network']['l3']['gateway_external_network_id'] = '000-NET-UUID-ALREADY-SET'
        chef_run.ruby_block('query gateway external network uuid').old_run_action(:create)
        expect(chef_run.node['openstack']['network']['l3']['gateway_external_network_id']).to eq '000-NET-UUID-ALREADY-SET'
      end
    end

    describe 'l3_agent.ini' do
      let(:file) { chef_run.template('/etc/neutron/l3_agent.ini') }

      it 'creates l3_agent.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end

      context 'template contents' do
        it_behaves_like 'custom template banner displayer' do
          let(:file_name) { file.name }
        end

        it_behaves_like 'common network attributes displayer' do
          let(:file_name) { file.name }
        end

        %w(handle_internal_only_routers external_network_bridge metadata_port send_arp_for_ha
           periodic_interval periodic_fuzzy_delay router_delete_namespaces).each do |attr|
          it "displays the #{attr} l3 attribute" do
            node.set['openstack']['network']['l3'][attr] = "network_l3_#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{attr} = network_l3_#{attr}_value$/)
          end
        end

        it 'sets the agent_mode attribute to dvr_snat' do
          node.set['openstack']['network']['l3']['router_distributed'] = true
          allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-network::server').and_return(true)
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^agent_mode = dvr_snat$/)
        end

        it 'sets the agent_mode attribute to dvr' do
          node.set['openstack']['network']['l3']['router_distributed'] = true
          allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-network::server').and_return(false)
          allow_any_instance_of(Chef::Recipe).to receive(:recipe_included?).with('openstack-compute::compute').and_return(true)
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^agent_mode = dvr$/)
        end

        it 'sets the ha_vrrp_advert_int attribute' do
          node.set['openstack']['network']['l3']['ha']['ha_vrrp_advert_int'] = 'ha_vrrp_advert_int_value'
          expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^ha_vrrp_advert_int = ha_vrrp_advert_int_value$/)
        end

        %w(router_id gateway_external_network_id).each do |conditional_attr|
          it "displays the #{conditional_attr} attribute when present" do
            node.set['openstack']['network']['l3'][conditional_attr] = "network_l3_#{conditional_attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/^#{conditional_attr} = network_l3_#{conditional_attr}_value$/)
          end

          it "does not display the #{conditional_attr} attribute if not set" do
            node.set['openstack']['network']['l3'][conditional_attr] = nil
            expect(chef_run).not_to render_file(file.name).with_content(/^#{conditional_attr} = /)
          end
        end
      end

      it 'notifies the l3 agent service' do
        expect(file).to notify('service[neutron-l3-agent]').to(:restart).immediately
      end
    end

    describe 'fwaas_driver.ini' do
      let(:file) { chef_run.template('/etc/neutron/fwaas_driver.ini') }

      it 'creates fwaas_driver.ini' do
        expect(chef_run).to create_template(file.name).with(
          user: 'neutron',
          group: 'neutron',
          mode: 0640
        )
      end

      context 'template contents' do
        it_behaves_like 'custom template banner displayer' do
          let(:file_name) { file.name }
        end

        it 'displays the fwaas section attributes when fwaas is enabled' do
          node.set['openstack']['network']['fwaas']['enabled'] = 'True'
          [/^driver = neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver$/, /^enabled = True$/].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('fwaas', line)
          end
        end

        it 'displays the fwaas section attributes when fwaas is not enabled' do
          [/^driver = neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver$/, /^enabled = False$/].each do |line|
            expect(chef_run).to render_config_file(file.name).with_section_content('fwaas', line)
          end
        end
      end

      it 'upgrades neutron fwaas package' do
        expect(chef_run).to upgrade_package('python-neutron-fwaas')
      end

      it 'notifies the l3 agent service when vpn is not enabled' do
        node.set['openstack']['network']['enable_vpn'] = false
        expect(file).to notify('service[neutron-l3-agent]').to(:restart).immediately
      end
    end

    describe 'create ovs bridges' do
      let(:iplink) { 'ip link set eth1 up' }
      let(:cmd) { 'ovs-vsctl add-br br-ex && ovs-vsctl add-port br-ex eth1' }

      it "doesn't add the external bridge if it already exists" do
        stub_command(/ovs-vsctl br-exists/).and_return(true)
        stub_command(/ip link show eth1/).and_return(true)

        expect(chef_run).to run_execute(iplink)
        expect(chef_run).not_to run_execute(cmd)
      end

      it "doesn't add the external bridge if the physical interface doesn't exist" do
        stub_command(/ovs-vsctl br-exists/).and_return(true)
        stub_command(/ip link show eth1/).and_return(false)

        expect(chef_run).to run_execute(iplink)
        expect(chef_run).not_to run_execute(cmd)
      end

      it 'adds the external bridge if it does not yet exist' do
        stub_command(/ovs-vsctl br-exists/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)

        expect(chef_run).to run_execute(iplink)
        expect(chef_run).to run_execute(cmd)
      end

      it 'adds the external bridge if the physical interface exists' do
        stub_command(/ovs-vsctl br-exists/).and_return(false)
        stub_command(/ip link show eth1/).and_return(true)

        expect(chef_run).to run_execute(iplink)
        expect(chef_run).to run_execute(cmd)
      end
    end
  end
end
