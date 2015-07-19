# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::hyperv' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'does not install neutron hyperv package when hyperv mech_driver is not included' do
      expect(chef_run).not_to upgrade_package('networking-hyperv')
    end

    it 'install neutron hyperv package when hyperv mech_driver is included' do
      node.set['openstack']['network']['ml2']['mechanism_drivers'] = 'hyperv'
      expect(chef_run).to upgrade_package('networking-hyperv')
    end
  end
end
