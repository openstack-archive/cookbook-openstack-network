# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'upgrades mysql python package' do
      expect(chef_run).to upgrade_package('MySQL-python')
    end
    it 'upgrades openstack-neutron-ml2 package' do
      expect(chef_run).to upgrade_package('openstack-neutron-ml2')
    end
  end
end
