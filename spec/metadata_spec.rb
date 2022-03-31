require_relative '../lib/movable_ink/aws'
require 'webmock/rspec'

describe MovableInk::AWS::Metadata do
  before(:each) do
    allow_any_instance_of(MovableInk::AWS).to receive(:sleep).and_return(true)
  end

  context 'outside ec2' do
    it 'should raise an error if the metadata service times out' do
      aws = MovableInk::AWS.new
      # stub an error making a request to the metadata api
      stub_request(:put, 'http://169.254.169.254/latest/api/token').to_raise(Net::OpenTimeout)
      expect{ aws.instance_id }.to raise_error(MovableInk::AWS::Errors::MetadataTimeout)
      expect{ aws.availability_zone }.to raise_error(MovableInk::AWS::Errors::MetadataTimeout)
    end

    it 'should raise an error if the metadata service times out on getting dynamic data' do
      aws = MovableInk::AWS.new
      # stub an error making a request to the metadata api
      stub_request(:put, 'http://169.254.169.254/latest/api/token').to_raise(Net::OpenTimeout)
      expect{ aws.instance_identity_document }.to raise_error(MovableInk::AWS::Errors::MetadataTimeout)
    end

    it 'should return nil if the metadata service returns unparseable dynamic data' do
      aws = MovableInk::AWS.new
      expect(aws).to receive(:retrieve_data).with('/latest/dynamic/instance-identity/document', {tries: 3}).and_return("something")
      expect(aws.instance_identity_document).to eq(nil)
    end

    it 'should raise an error if trying to load private_ipv4 outside of EC2' do
      aws = MovableInk::AWS.new
      # stub an error making a request to the metadata api
      stub_request(:put, 'http://169.254.169.254/latest/api/token').to_raise(Net::OpenTimeout)
      expect{ aws.private_ipv4 }.to raise_error(MovableInk::AWS::Errors::MetadataTimeout)
    end
  end

  context 'inside ec2' do
    it 'calls the EC2 metadata service to get the private ipv4 address of the instance' do
      aws = MovableInk::AWS.new
      allow(aws).to receive(:retrieve_metadata).with('local-ipv4').and_return('10.0.0.1')
      expect(aws.private_ipv4).to eq('10.0.0.1')
    end

    it 'calls the EC2 metadata service to get the instance ID' do
      aws = MovableInk::AWS.new
      expect(aws).to receive(:retrieve_metadata).with('instance-id').and_return("i-12345")
      expect(aws.instance_id).to eq('i-12345')
    end

    it 'calls the EC2 metadata service to get the availability zone' do
      aws = MovableInk::AWS.new
      expect(aws).to receive(:retrieve_metadata).with('placement/availability-zone').and_return("us-east-1a")
      expect(aws.availability_zone).to eq('us-east-1a')
    end
  end
end
