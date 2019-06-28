require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::Autoscaling do
  let(:aws) { MovableInk::AWS.new }
  let(:autoscaling) { Aws::AutoScaling::Client.new(stub_responses: true) }
  let(:ec2) { Aws::EC2::Client.new(stub_responses: true) }
  let(:set_instance_health_data) { autoscaling.stub_data(:set_instance_health, {}) }
  let(:complete_lifecycle_action_data) { autoscaling.stub_data(:complete_lifecycle_action, {}) }
  let(:record_lifecycle_action_heartbeat_data) { autoscaling.stub_data(:record_lifecycle_action_heartbeat, {}) }
  let(:create_tags_data) { ec2.stub_data(:create_tags, {}) }
  let(:delete_tags_data) { ec2.stub_data(:delete_tags, {}) }

  it 'should mark an instance as unhealthy' do
    autoscaling.stub_responses(:set_instance_health, set_instance_health_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:instance_id).and_return('i-12345')
    allow(aws).to receive(:autoscaling).and_return(autoscaling)

    expect(aws.mark_me_as_unhealthy).to eq(Aws::EmptyStructure.new)
  end

  it "should mark an instance as healthy" do
    ec2.stub_responses(:create_tags, create_tags_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:instance_id).and_return('i-12345')
    allow(aws).to receive(:ec2).and_return(ec2)

    expect(aws.mark_me_as_healthy(role: 'some_role')).to eq(Aws::EmptyStructure.new)
  end

  it "should remove role tags" do
    ec2.stub_responses(:delete_tags, delete_tags_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:instance_id).and_return('i-12345')
    allow(aws).to receive(:ec2).and_return(ec2)

    expect(aws.delete_role_tag(role: 'some_role')).to eq(Aws::EmptyStructure.new)
  end

  it "should complete lifecycle actions" do
    autoscaling.stub_responses(:complete_lifecycle_action, complete_lifecycle_action_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:autoscaling).and_return(autoscaling)

    expect(autoscaling).to receive(:complete_lifecycle_action).with({
      lifecycle_action_result: 'CONTINUE',
      lifecycle_action_token: 'token',
      lifecycle_hook_name: 'hook',
      auto_scaling_group_name: 'group',
    }).and_call_original
    expect(aws.complete_lifecycle_action(lifecycle_hook_name: 'hook', auto_scaling_group_name: 'group', lifecycle_action_token: 'token')).to eq(Aws::EmptyStructure.new)
  end

  it 'allows passing the instance_id to complete a lifecycle action' do
    autoscaling.stub_responses(:complete_lifecycle_action, complete_lifecycle_action_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:autoscaling).and_return(autoscaling)

    expect(autoscaling).to receive(:complete_lifecycle_action).with({
      lifecycle_action_result: 'CONTINUE',
      lifecycle_hook_name: 'hook',
      instance_id: 'i-987654321',
      auto_scaling_group_name: 'group'
    }).and_call_original
    expect(aws.complete_lifecycle_action(lifecycle_hook_name: 'hook', auto_scaling_group_name: 'group', instance_id: 'i-987654321')).to eq(Aws::EmptyStructure.new)
  end

  it 'should record lifecycle action heartbeats' do
    autoscaling.stub_responses(:record_lifecycle_action_heartbeat, record_lifecycle_action_heartbeat_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:autoscaling).and_return(autoscaling)

    expect(autoscaling).to receive(:record_lifecycle_action_heartbeat).with({
      lifecycle_action_token: 'token',
      lifecycle_hook_name: 'hook',
      auto_scaling_group_name: 'group'
    }).and_call_original
    expect(aws.record_lifecycle_action_heartbeat(lifecycle_hook_name: 'hook', auto_scaling_group_name: 'group', lifecycle_action_token: 'token')).to eq(Aws::EmptyStructure.new)
  end

  it 'allows passing the instance_id to record lifecycle action heartbeats' do
    autoscaling.stub_responses(:record_lifecycle_action_heartbeat, record_lifecycle_action_heartbeat_data)
    allow(aws).to receive(:my_region).and_return('us-east-1')
    allow(aws).to receive(:autoscaling).and_return(autoscaling)

    expect(autoscaling).to receive(:record_lifecycle_action_heartbeat).with({
      instance_id: 'i-987654321',
      lifecycle_hook_name: 'hook',
      auto_scaling_group_name: 'group'
    }).and_call_original
    expect(aws.record_lifecycle_action_heartbeat(lifecycle_hook_name: 'hook', auto_scaling_group_name: 'group', instance_id: 'i-987654321')).to eq(Aws::EmptyStructure.new)
  end
end
