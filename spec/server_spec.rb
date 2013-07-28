require_relative 'spec_helper'

describe 'openstack-network::server' do
  before { quantum_stubs }
  before do
    @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS do |n|
      n.set["openstack"]["mq"] = {
        "host" => "127.0.0.1"
      }
    end
    @chef_run.converge "openstack-network::server"
  end

  describe "package and servicess" do

    it "installs quantum packages" do
      expect(@chef_run).to install_package "quantum-server"
    end

    it "installs metadata packages" do
      expect(@chef_run).to install_package "quantum-metadata-agent"
    end

    it "starts metadata service" do
      expect(@chef_run).to enable_service "quantum-metadata-agent"
    end

  end

  describe "quantum.conf" do

    before do
     @file = @chef_run.template "/etc/quantum/quantum.conf"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "quantum", "quantum"
    end

    it "has proper modes" do
     expect(sprintf("%o", @file.mode)).to eq "644"
    end

    it "has rabbit_host" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_host=127.0.0.1"
    end

    it "does not have rabbit_hosts" do
      expect(@chef_run).not_to create_file_with_content @file.name,
        "rabbit_hosts="
    end

    it "does not have rabbit_ha_queues" do
      expect(@chef_run).not_to create_file_with_content @file.name,
        "rabbit_ha_queues="
    end

    it "has rabbit_port" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_port=5672"
    end

    it "has rabbit_userid" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_userid=guest"
    end

    it "has rabbit_password" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_password=rabbit-pass"
    end

    it "has rabbit_virtual_host" do
      expect(@chef_run).to create_file_with_content @file.name,
        "rabbit_virtual_host=/"
    end

    describe "quantum.conf with rabbit ha" do

      before do
        @chef_run = ::ChefSpec::ChefRunner.new(::UBUNTU_OPTS) do |n|
          n.set["openstack"]["network"]["rabbit"]["ha"] = true
        end
        @chef_run.converge "openstack-network::server"
      end
  
      it "has rabbit_hosts" do
        expect(@chef_run).to create_file_with_content @file.name,
          "rabbit_hosts=1.1.1.1:5672,2.2.2.2:5672"
      end
  
      it "has rabbit_ha_queues" do
        expect(@chef_run).to create_file_with_content @file.name,
          "rabbit_ha_queues=True"
      end
  
      it "does not have rabbit_host" do
        expect(@chef_run).not_to create_file_with_content @file.name,
          "rabbit_host=127.0.0.1"
      end
  
      it "does not have rabbit_port" do
        expect(@chef_run).not_to create_file_with_content @file.name,
          "rabbit_port=5672"
      end
    end
  end
end
