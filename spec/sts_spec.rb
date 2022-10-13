require_relative '../lib/movable_ink/aws'
require 'webmock/rspec'

describe MovableInk::AWS::STS do

  before(:all) { WebMock.enable! }
  after(:all) { WebMock.disable! }

  let(:stubbed_sts_client) { Aws::STS::Client.new(stub_responses: true) }

  before(:each) do
    allow_any_instance_of(MovableInk::AWS).to receive(:sleep).and_return(true)
    allow(Aws::STS::Client).to receive(:new).and_return(stubbed_sts_client)
    allow(stubbed_sts_client).to receive(:get_caller_identity).and_return(arn: 'arn:aws:sts::817035293158:assumed-role/AWSReservedSSO_AdministratorAccess_dbcbe2228fe1d700/sre')
  end

  context "outside EC2" do

    it "it should return the assume role used with AWS SSO" do
      aws = MovableInk::AWS.new
      stubbed_sts_client.stub_responses('arn:aws:sts::817035293158:assumed-role/AWSReservedSSO_AdministratorAccess_dbcbe2228fe1d700/sre')
      allow(aws).to receive(:stubbed_sts_client).and_return(stubbed_sts_client)
    end

    context 'get_caller_identity' do
      it 'it should return the sts client' do
        aws = MovableInk::AWS.new
        stubbed_sts_client.stub_responses(:get_caller_identity, :my_region)
        allow(aws).to receive(:stubbed_sts_client).and_return(stubbed_sts_client)
      end
    end
  end
end
