# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'upgrades mysql python package' do
      expect(chef_run).to upgrade_package('MySQL-python')
    end

    it 'upgrades db2 python packages if explicitly told' do
      node.set['openstack']['db']['network']['service_type'] = 'db2'

      ['python-ibm-db', 'python-ibm-db-sa'].each do |pkg|
        expect(chef_run).to upgrade_package(pkg)
      end
    end

    describe 'ml2_conf.ini' do
      let(:file) { chef_run.template('/etc/neutron/plugins/ml2/ml2_conf.ini') }

      it 'create plugin.ini symlink' do
        expect(chef_run).to create_link('/etc/neutron/plugin.ini').with(
          to: file.name,
          owner: 'neutron',
          group: 'neutron'
        )
      end
      it 'does not include the ovs section' do
        expect(chef_run).not_to render_file(file.name).with_content(/^[OVS]/)
      end
    end
  end
end
