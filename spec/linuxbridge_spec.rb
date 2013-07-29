require_relative 'spec_helper'

describe 'openstack-network::linuxbridge' do

  describe "ubuntu" do
    before do
      quantum_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      @chef_run.converge "openstack-network::linuxbridge"
    end

    describe "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini" do
      before do
        @file = @chef_run.template(
          "/etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini")
      end

      it "has proper owner" do
        expect(@file).to be_owned_by "quantum", "quantum"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "644"
      end

      it "has a correct sql_connection value" do
        expect(@chef_run).to create_file_with_content(
          @file.name, "mysql://quantum:quantum-pass@127.0.0.1:3306/quantum")
      end
    end
  end
end
