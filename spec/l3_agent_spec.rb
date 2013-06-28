require_relative 'spec_helper'

describe 'openstack-network::l3_agent' do

  describe "ubuntu" do

    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      @chef_run.converge "openstack-network::l3_agent"
    end

    it "installs quamtum l3 package" do
      expect(@chef_run).to install_package "quantum-l3-agent"
    end

  end

end
