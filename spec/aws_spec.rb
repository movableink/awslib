require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS do
  context "outside EC2" do
    it 'doesnt raise an error if instance_id is set' do
      aws = MovableInk::AWS.new(instance_id: 'i-987654321')
      expect(aws.instance_id).to eq('i-987654321')
    end
  end

  context "inside EC2" do
    it "should find the datacenter by region" do
      aws = MovableInk::AWS.new
      expect(aws).to receive(:retrieve_metadata).with('placement/availability-zone').and_return("us-east-1a")
      expect(aws.datacenter).to eq('iad')
    end

    context "MovableInk::AWS#run_with_backoff" do
      it "should retry when throttled with increasing timeouts" do
        aws = MovableInk::AWS.new(environment: 'test')
        ec2 = Aws::EC2::Client.new(stub_responses: true)
        ec2.stub_responses(:describe_instances, 'RequestLimitExceeded')

        expect(aws).to receive(:notify_slack).exactly(10).times
        expect(aws).to receive(:sleep).exactly(9).times.and_return(true)
        expect(STDOUT).to receive(:puts).exactly(10).times

        aws.run_with_backoff { ec2.describe_instances } rescue nil
      end

      it "should not retry and raise if a non-throttling error occurs" do
        aws = MovableInk::AWS.new(environment: 'test')
        route53 = Aws::Route53::Client.new(stub_responses: true)
        route53.stub_responses(:list_resource_record_sets, 'NoSuchHostedZone')

        expect(aws).to receive(:notify_slack).exactly(1).times
        expect(STDOUT).to receive(:puts).exactly(1).times
        expect{ aws.run_with_backoff { route53.list_resource_record_sets(hosted_zone_id: 'foo') } }.to raise_error(MovableInk::AWS::Errors::ServiceError)
      end

      it "should not notify slack when quiet param is passed in" do
        aws = MovableInk::AWS.new(environment: 'test')
        ec2 = Aws::EC2::Client.new(stub_responses: true)
        ec2.stub_responses(:describe_instances, 'RequestLimitExceeded')

        expect(aws).to receive(:notify_slack).exactly(2).times
        expect(aws).to receive(:sleep).exactly(9).times.and_return(true)
        expect(STDOUT).to receive(:puts).exactly(2).times

        aws.run_with_backoff(quiet: true) { ec2.describe_instances } rescue nil
      end

      it "should raise an error after too many timeouts" do
        aws = MovableInk::AWS.new(environment: 'test')
        ec2 = Aws::EC2::Client.new(stub_responses: true)
        ec2.stub_responses(:describe_instances, 'RequestLimitExceeded')

        expect(aws).to receive(:notify_and_sleep).exactly(9).times
        expect(aws).to receive(:notify_slack).exactly(1).times
        expect(STDOUT).to receive(:puts).exactly(1).times
        expect{ aws.run_with_backoff { ec2.describe_instances } }.to raise_error(MovableInk::AWS::Errors::FailedWithBackoff)
      end
    end
  end
end
