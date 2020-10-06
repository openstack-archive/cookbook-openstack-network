require_relative 'spec_helper'

describe 'openstack-network' do
  describe 'redhat' do
    let(:runner) { ChefSpec::SoloRunner.new(REDHAT_OPTS) }
    let(:node) { runner.node }
    cached(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'neutron-stubs'

    pkgs =
      %w(
        ebtables
        iproute
        openstack-neutron
        openstack-neutron-ml2
      )
    it do
      expect(chef_run).to upgrade_package(pkgs)
    end
    it do
      expect(chef_run).to upgrade_package('MySQL-python')
    end
    it do
      expect(chef_run).to create_cookbook_file('/usr/bin/neutron-enable-bridge-firewall.sh').with(
        source: 'neutron-enable-bridge-firewall.sh',
        owner: 'root',
        group: 'wheel',
        mode: '0755'
      )
    end
  end
end
