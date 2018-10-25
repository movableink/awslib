require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::SNS do
  let(:aws) { MovableInk::AWS.new }
  let(:sns) { Aws::SNS::Client.new(stub_responses: true) }
  let(:topic_data) { sns.stub_data(:list_topics, topics: [
      {
        topic_arn: 'slack-aws-alerts'
      }
    ])
  }
  let(:publish_response) { sns.stub_data(:publish, message_id: 'messageId')}

  it "should find the slack sns topic" do
    sns.stub_responses(:list_topics, topic_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:sns).and_return(sns)

    expect(aws.sns_slack_topic_arn).to eq('slack-aws-alerts')
  end

  it "should notify with the specified subject and message" do
    sns.stub_responses(:list_topics, topic_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:instance_id).and_return('test instance')
    allow(aws).to receive(:sns).and_return(sns)

    expect(aws.notify_slack(subject: 'Test subject', message: 'Test message').message_id).to eq('messageId')

  end

  it "should truncate subjects longer than 100 characters" do
    sns.stub_responses(:list_topics, topic_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:instance_id).and_return('test instance')

    allow(aws).to receive(:sns).and_return(sns)
    message = 'Test message'
    subject = "a"*100
    expected_subject = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa (test instance, us-east-1)"
    expect(sns).to receive(:publish).with({:topic_arn=>"slack-aws-alerts", :message=>"Test message", :subject => expected_subject})

    aws.notify_slack(subject: subject, message: message)

  end
end
