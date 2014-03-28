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

    it 'does not install python-neutronclient when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      expect(chef_run).to_not install_package('python-neutronclient')
    end

    it 'upgrades python neutronclient' do
      expect(chef_run).to upgrade_package('python-neutronclient')
    end

    it 'upgrades python pyparsing' do
      expect(chef_run).to upgrade_package('python-pyparsing')
    end

    it 'installs mysql python packages by default' do
      expect(chef_run).to install_package('python-mysqldb')
    end

  end
end
