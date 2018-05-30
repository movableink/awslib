require 'aws-sdk'
require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::EC2 do
  context "outside EC2" do
    it "should raise an error if trying to load mi_env outside of EC2" do
      aws = MovableInk::AWS.new
      expect{ aws.mi_env }.to raise_error(MovableInk::AWS::Errors::EC2Required)
    end

    it "should use the provided environment" do
      aws = MovableInk::AWS.new(environment: 'test')
      expect(aws.mi_env).to eq('test')
    end
  end

  context "inside EC2" do
    let(:aws) { MovableInk::AWS.new }
    let(:ec2) { Aws::EC2::Client.new(stub_responses: true) }
    let(:tag_data) { ec2.stub_data(:describe_tags, tags: [
        {
          key: 'mi:env',
          value: 'test'
        }
      ])
    }

    it "should find the environment from the current instance's tags" do
      ec2.stub_responses(:describe_tags, tag_data)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      allow(aws).to receive(:instance_id).and_return('i-12345')
      allow(aws).to receive(:ec2).and_return(ec2)

      expect(aws.mi_env).to eq('test')
    end

    context "thopter" do
      let(:thopter_data) { ec2.stub_data(:describe_instances, reservations: [
        instances: [
          {
            tags: [
              {
                key: 'mi:env',
                value: 'test'
              },
              {
                key: 'mi:roles',
                value: 'thopter'
              },
              {
                key: 'Name',
                value: 'thopter'
              }
            ],
            private_ip_address: '1.2.3.4'
          }
        ]])
      }

      it "should find the thopter instance" do
        ec2.stub_responses(:describe_instances, thopter_data)
        allow(aws).to receive(:mi_env).and_return('test')
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.thopter_instance.count).to eq(1)
      end

      it "should find the thopter instance's private IP" do
        ec2.stub_responses(:describe_instances, thopter_data)
        allow(aws).to receive(:mi_env).and_return('test')
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.thopter).to eq('1.2.3.4')
      end
    end

    context "statsd" do
      let(:availability_zone) { 'us-east-1a' }
      let(:statsd_data) { ec2.stub_data(:describe_instances, reservations: [
        instances: [
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'statsd'
              }
            ],
            private_ip_address: '10.0.0.1',
            placement: {
              availability_zone: availability_zone
            }
          },
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'statsd'
              }
            ],
            private_ip_address: '10.0.0.2',
            placement: {
              availability_zone: availability_zone
            }
          },
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'something_else'
              }
            ],
            private_ip_address: '10.0.0.3',
            placement: {
              availability_zone: availability_zone
            }
          }
        ]])
      }

      it "should find one of the statsd hosts" do
        ec2.stub_responses(:describe_instances, statsd_data)
        allow(aws).to receive(:mi_env).and_return('test')
        allow(aws).to receive(:availability_zone).and_return(availability_zone)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(['10.0.0.1', '10.0.0.2']).to include(aws.statsd_host)
        expect(['10.0.0.1', '10.0.0.2']).to include(aws.statsd_host)
      end
    end

    context "ordered roles" do
      let(:my_availability_zone) { 'us-east-1a' }
      let(:other_availability_zone) { 'us-east-1b' }
      let(:instance_data) { ec2.stub_data(:describe_instances, reservations: [
        instances: [
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'app_db_replica'
              }
            ],
            private_ip_address: '10.0.0.1',
            placement: {
              availability_zone: my_availability_zone
            }
          },
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'app_db_replica'
              }
            ],
            private_ip_address: '10.0.0.2',
            placement: {
              availability_zone: other_availability_zone
            }
          }
        ]])
      }

      it "should find hosts and order them with my AZ first" do
        ec2.stub_responses(:describe_instances, instance_data)
        allow(aws).to receive(:mi_env).and_return('test')
        allow(aws).to receive(:availability_zone).and_return(my_availability_zone)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.instance_ip_addresses_by_role_ordered(role: 'app_db_replica').count).to eq(2)
        expect(aws.instance_ip_addresses_by_role_ordered(role: 'app_db_replica').first).to eq('10.0.0.1')
        expect(aws.instance_ip_addresses_by_role_ordered(role: 'app_db_replica').last).to eq('10.0.0.2')
      end
    end

    context "redii" do
      let(:port) { 6379 }
      let(:availability_zone) { 'us-east-1a' }
      let(:redis_data) { ec2.stub_data(:describe_instances, reservations: [
        instances: [
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'visitor_redis'
              }
            ],
            private_ip_address: '10.0.0.1',
            placement: {
              availability_zone: availability_zone
            }
          },
          {
            tags: [
              {
                key: 'mi:roles',
                value: 'visitor_redis'
              }
            ],
            private_ip_address: '10.0.0.2',
            placement: {
              availability_zone: availability_zone
            }
          }
        ]])
      }
      let(:redii) { [{"host" => '10.0.0.1', "port" => 6379},{"host" => '10.0.0.2', "port" => 6379}] }

      it "should return redis IPs and ports" do
        ec2.stub_responses(:describe_instances, redis_data)
        allow(aws).to receive(:mi_env).and_return('test')
        allow(aws).to receive(:availability_zone).and_return(availability_zone)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.redis_by_role('visitor_redis', port)).to match_array(redii)
      end
    end

    context "elastic IPs" do
      let(:elastic_ip_data) { ec2.stub_data(:describe_addresses, addresses: [
          {
            allocation_id: "eipalloc-1",
            association_id: "eipassoc-1",
            domain: "vpc",
            public_ip: "1.1.1.1",
            tags: [{
              key: 'mi:role',
              value: 'some_role'
            }]
          },
          {
            allocation_id: "eipalloc-2",
            association_id: "eipassoc-2",
            domain: "vpc",
            public_ip: "1.1.1.2",
            tags: [{
              key: 'mi:role',
              value: 'some_role'
            }]
          },
          {
            allocation_id: "eipalloc-3",
            association_id: nil,
            domain: "vpc",
            public_ip: "1.1.1.3",
            tags: [{
              key: 'mi:role',
              value: 'some_role'
            }]
          }
        ])
      }
      let(:associate_address_data) { ec2.stub_data(:associate_address, association_id: 'eipassoc-3') }

      it "should find all elastic IPs" do
        ec2.stub_responses(:describe_addresses, elastic_ip_data)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.elastic_ips.count).to eq(3)
        expect(aws.elastic_ips.first.public_ip).to eq('1.1.1.1')
        expect(aws.elastic_ips.last.public_ip).to eq('1.1.1.3')
      end

      it "should find unassigned elastic IPs" do
        ec2.stub_responses(:describe_addresses, elastic_ip_data)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.unassigned_elastic_ips.count).to eq(1)
        expect(aws.unassigned_elastic_ips.first.public_ip).to eq('1.1.1.3')
      end

      it "should filter reserved IPs to get available IPs" do
        ec2.stub_responses(:describe_addresses, elastic_ip_data)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.available_elastic_ips(role: 'some_role').count).to eq(1)
        expect(aws.available_elastic_ips(role: 'some_role').first['public_ip']).to eq('1.1.1.3')
      end

      it "should assign an elastic IP" do
        ec2.stub_responses(:describe_addresses, elastic_ip_data)
        ec2.stub_responses(:associate_address, associate_address_data)
        allow(aws).to receive(:my_region).and_return('us-east-1')
        allow(aws).to receive(:instance_id).and_return('i-12345')
        allow(aws).to receive(:ec2).and_return(ec2)

        expect(aws.assign_ip_address(role: 'some_role').association_id).to eq('eipassoc-3')
      end
    end
  end
end
