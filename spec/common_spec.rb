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

      it 'has proper owner' do
        expect(file.owner).to eq('neutron')
        expect(file.group).to eq('neutron')
      end

      it 'has proper modes' do
        expect(sprintf('%o', file.mode)).to eq '644'
      end

      it 'has default core plugin' do
        expect(chef_run).to render_file(file.name).with_content(
          /^core_plugin = neutron.plugins.ml2.plugin.Ml2Plugin/)
      end

      it 'has bind_host set' do
        node.set['openstack']['endpoints']['network-api-bind']['host'] = '1.1.1.1'
        expect(chef_run).to render_file(file.name).with_content('bind_host = 1.1.1.1')
      end

      it 'has bind_port set' do
        node.set['openstack']['endpoints']['network-api-bind']['port'] = '9999'
        expect(chef_run).to render_file(file.name).with_content('bind_port = 9999')
      end

      it 'templates misc_neutron array correctly' do
        node.set['openstack']['network']['misc_neutron'] = ['MISC1=OPTION1', 'MISC2=OPTION2']
        expect(chef_run).to render_file(file.name).with_content(
          /^MISC1=OPTION1$/)
        expect(chef_run).to render_file(file.name).with_content(
          /^MISC2=OPTION2$/)
      end

      # TODO: flush out rest of template attributes
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
  end
end
