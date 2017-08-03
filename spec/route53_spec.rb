require 'aws-sdk'
require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::Route53 do
  let(:aws) { MovableInk::AWS.new }

  context "elastic IPs" do
    let(:ec2) { Aws::EC2::Client.new(stub_responses: true) }
    let(:s3) { Aws::S3::Client.new(stub_responses: true) }
    let(:elastic_ip_data) { ec2.stub_data(:describe_addresses, addresses: [
        {
          allocation_id: "eipalloc-1",
          association_id: "eipassoc-1",
          domain: "vpc",
          public_ip: "1.1.1.1"
        },
        {
          allocation_id: "eipalloc-2",
          association_id: "eipassoc-2",
          domain: "vpc",
          public_ip: "1.1.1.2"
        },
        {
          allocation_id: "eipalloc-3",
          association_id: nil,
          domain: "vpc",
          public_ip: "1.1.1.3"
        }
      ])
    }
    let(:associate_address_data) { ec2.stub_data(:associate_address, association_id: 'eipassoc-3') }
    let(:reserved_ips) { StringIO.new(
      "{\"datacenter\":\"iad\",\"allocation_id\":\"eipalloc-1\",\"public_ip\":\"1.1.1.1\",\"role\":\"some_role\"}
       {\"datacenter\":\"iad\",\"allocation_id\":\"eipalloc-2\",\"public_ip\":\"1.1.1.2\",\"role\":\"some_role\"}
       {\"datacenter\":\"iad\",\"allocation_id\":\"eipalloc-3\",\"public_ip\":\"1.1.1.3\",\"role\":\"some_role\"}"
    )}
    let(:s3_reserved_ips_data) { s3.stub_data(:get_object, body: reserved_ips) }

    it "should find all elastic IPs" do
      ec2.stub_responses(:describe_addresses, elastic_ip_data)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      allow(aws).to receive(:instance_id).and_return('i-12345')
      allow(aws).to receive(:ec2).and_return(ec2)

      expect(aws.elastic_ips.count).to eq(3)
      expect(aws.elastic_ips.first.public_ip).to eq('1.1.1.1')
      expect(aws.elastic_ips.last.public_ip).to eq('1.1.1.3')
    end

    it "should find unassigned elastic IPs" do
      ec2.stub_responses(:describe_addresses, elastic_ip_data)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      allow(aws).to receive(:instance_id).and_return('i-12345')
      allow(aws).to receive(:ec2).and_return(ec2)

      expect(aws.unassigned_elastic_ips.count).to eq(1)
      expect(aws.unassigned_elastic_ips.first.public_ip).to eq('1.1.1.3')
    end

    it "should load reserved elastic IPs from S3" do
      s3.stub_responses(:get_object, s3_reserved_ips_data)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      allow(aws).to receive(:instance_id).and_return('i-12345')
      allow(aws).to receive(:s3).and_return(s3)

      expect(aws.reserved_elastic_ips.count).to eq(3)
    end

    it "should filter reserved IPs to get available IPs" do
      ec2.stub_responses(:describe_addresses, elastic_ip_data)
      s3.stub_responses(:get_object, s3_reserved_ips_data)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      allow(aws).to receive(:instance_id).and_return('i-12345')
      allow(aws).to receive(:ec2).and_return(ec2)
      allow(aws).to receive(:s3).and_return(s3)

      expect(aws.available_elastic_ips(role: 'some_role').count).to eq(1)
      expect(aws.available_elastic_ips(role: 'some_role').first['public_ip']).to eq('1.1.1.3')
    end

    it "should assign an elastic IP" do
      ec2.stub_responses(:describe_addresses, elastic_ip_data)
      ec2.stub_responses(:associate_address, associate_address_data)
      s3.stub_responses(:get_object, s3_reserved_ips_data)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      allow(aws).to receive(:instance_id).and_return('i-12345')
      allow(aws).to receive(:ec2).and_return(ec2)
      allow(aws).to receive(:s3).and_return(s3)

      expect(aws.assign_ip_address(role: 'some_role').association_id).to eq('eipassoc-3')
    end
  end

  context "resource record sets" do
    let(:route53) { Aws::Route53::Client.new(stub_responses: true) }
    let(:rrset_data) { route53.stub_data(:list_resource_record_sets, resource_record_sets: [
        {
          name: 'host1.domain.tld.'
        },
        {
          name: 'host2.domain.tld.'
        }
      ])
    }

    it "should retrieve all rrsets for zone" do
      route53.stub_responses(:list_resource_record_sets, rrset_data)
      allow(aws).to receive(:route53).and_return(route53)

      expect(aws.resource_record_sets('Z123').count).to eq(2)
      expect(aws.resource_record_sets('Z123').first.name).to eq('host1.domain.tld.')
      expect(aws.resource_record_sets('Z123').last.name).to eq('host2.domain.tld.')
    end
  end
end
