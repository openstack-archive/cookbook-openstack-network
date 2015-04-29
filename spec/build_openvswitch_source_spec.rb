# Encoding: utf-8
require_relative 'spec_helper'

describe 'openstack-network::build_openvswitch_source' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['compute']['network']['service_type'] = 'neutron'

      runner.converge('openstack-network::openvswitch')
      runner.converge(described_recipe)
    end
    let(:ovs_switch) { chef_run.dpkg_package('openvswitch-switch') }
    let(:ovs_dkms) { chef_run.dpkg_package('openvswitch-datapath-dkms') }
    let(:ovs_pki) { chef_run.dpkg_package('openvswitch-pki') }
    let(:ovs_common) { chef_run.dpkg_package('openvswitch-common') }

    include_context 'neutron-stubs'

    it 'does not install openvswitch build dependencies when nova networking' do
      node.override['openstack']['compute']['network']['service_type'] = 'nova'

      %w(build-essential pkg-config fakeroot libssl-dev openssl debhelper autoconf).each do |pkg|
        expect(chef_run).to_not install_package(pkg)
      end
    end

    # since our mocked version of ubuntu is precise, our compile
    # utilities should be installed to build OVS from source
    it 'installs openvswitch build dependencies' do
      %w(build-essential pkg-config fakeroot libssl-dev openssl debhelper autoconf dkms python-all python-qt4 python-zopeinterface python-twisted-conch).each do |pkg|
        expect(chef_run).to install_package(pkg)
      end
    end

    it 'installs openvswitch switch dpkg' do
      ovs_switch.source.should include 'openvswitch-switch_1.10.2-1_amd64.deb'
      ovs_switch.action.should eq [:nothing]
      expect(chef_run).to_not install_dpkg_package(ovs_switch.name)
    end

    it 'installs openvswitch datapath dkms dpkg' do
      ovs_dkms.source.should include 'openvswitch-datapath-dkms_1.10.2-1_all.deb'
      ovs_dkms.action.should eq [:nothing]
      expect(chef_run).to_not install_dpkg_package(ovs_dkms.name)
    end

    it 'installs openvswitch pki dpkg' do
      ovs_pki.source.should include 'openvswitch-pki_1.10.2-1_all.deb'
      ovs_pki.action.should eq [:nothing]
      expect(chef_run).to_not install_dpkg_package(ovs_pki.name)
    end

    it 'installs openvswitch common dpkg' do
      ovs_common.source.should include 'openvswitch-common_1.10.2-1_amd64.deb'
      ovs_common.action.should eq [:nothing]
      expect(chef_run).to_not install_dpkg_package(ovs_common.name)
    end
  end
end
