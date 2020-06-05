require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::Metadata do
  context 'outside ec2' do
    it 'should raise an error if EC2 is required' do
      aws = MovableInk::AWS.new
      allow(aws).to receive(:retrieve_metadata).with('instance-id').and_return("")
      allow(aws).to receive(:retrieve_metadata).with('placement/availability-zone').and_return("")

      expect{ aws.instance_id }.to raise_error(MovableInk::AWS::Errors::EC2Required)
      expect{ aws.availability_zone }.to raise_error(MovableInk::AWS::Errors::EC2Required)
    end

    it 'should raise an error if trying to load private_ipv4 outside of EC2' do
      aws = MovableInk::AWS.new
      allow(aws).to receive(:retrieve_metadata).with('local-ipv4').and_return('')
      expect{ aws.private_ipv4 }.to raise_error(MovableInk::AWS::Errors::EC2Required)
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
