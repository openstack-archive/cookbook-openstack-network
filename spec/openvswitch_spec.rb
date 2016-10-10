# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::openvswitch' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    it 'upgrades openvswitch switch' do
      expect(chef_run).to upgrade_package 'openvswitch-switch'
    end

    it 'upgrades linux bridge utils' do
      expect(chef_run).to upgrade_package 'bridge-utils'
    end

    it 'sets the openvswitch service to start on boot' do
      expect(chef_run).to enable_service 'openvswitch-switch'
    end

    it 'start the openvswitch service' do
      expect(chef_run).to start_service 'openvswitch-switch'
    end
  end
end
