# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::common' do
  describe 'redhat' do
    let(:runner) { ChefSpec::Runner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    it 'installs mysql python packages by default' do
      expect(chef_run).to install_package('MySQL-python')
    end

    it 'installs db2 python packages if explicitly told' do
      node.set['openstack']['db']['network']['service_type'] = 'db2'

      ['python-ibm-db', 'python-ibm-db-sa'].each do |pkg|
        expect(chef_run).to install_package(pkg)
      end
    end
  end
end
