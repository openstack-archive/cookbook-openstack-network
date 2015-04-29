# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-network::client' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    it 'upgrades python neutron client package' do
      expect(chef_run).to upgrade_package('python-neutronclient')
      expect(chef_run).to upgrade_package('python-pyparsing')
    end
  end
end
