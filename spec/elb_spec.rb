require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::ELB do
  let(:aws) { MovableInk::AWS.new(availability_zone: 'us-east-1a') }

  context 'alb_addresses' do
    let(:elbv2) { Aws::ElasticLoadBalancingV2::Client.new(stub_responses: true) }

    it "should return ALB IP addresses with availability zones" do
      lb_data = elbv2.stub_data(:describe_load_balancers, load_balancers: [{
        load_balancer_name: 'test-alb',
        load_balancer_arn: 'arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test-alb/50dc6c495c0c9188',
        availability_zones: [
          {
            zone_name: 'us-east-1a',
            subnet_id: 'subnet-12345',
            load_balancer_addresses: [
              { ip_address: '10.0.1.5' }
            ]
          },
          {
            zone_name: 'us-east-1b',
            subnet_id: 'subnet-67890',
            load_balancer_addresses: [
              { ip_address: '10.0.2.7' }
            ]
          }
        ]
      }])

      elbv2.stub_responses(:describe_load_balancers, lb_data)
      allow(aws).to receive(:elbv2_with_retries).and_return(elbv2)

      addresses = aws.alb_addresses(name: 'test-alb')
      expect(addresses.count).to eq(2)
      expect(addresses[0].ip_address).to eq('10.0.1.5')
      expect(addresses[0].availability_zone).to eq('us-east-1a')
      expect(addresses[0].subnet_id).to eq('subnet-12345')
      expect(addresses[1].ip_address).to eq('10.0.2.7')
      expect(addresses[1].availability_zone).to eq('us-east-1b')
      expect(addresses[1].subnet_id).to eq('subnet-67890')
    end

    it "should handle ALBs with no IP addresses" do
      lb_data = elbv2.stub_data(:describe_load_balancers, load_balancers: [{
        load_balancer_name: 'test-alb',
        load_balancer_arn: 'arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test-alb/50dc6c495c0c9188',
        availability_zones: [
          {
            zone_name: 'us-east-1a',
            subnet_id: 'subnet-12345',
            load_balancer_addresses: []
          }
        ]
      }])

      elbv2.stub_responses(:describe_load_balancers, lb_data)
      allow(aws).to receive(:elbv2_with_retries).and_return(elbv2)

      addresses = aws.alb_addresses(name: 'test-alb')
      expect(addresses.count).to eq(0)
    end

    it "should raise error when load balancer not found" do
      lb_data = elbv2.stub_data(:describe_load_balancers, load_balancers: [])

      elbv2.stub_responses(:describe_load_balancers, lb_data)
      allow(aws).to receive(:elbv2_with_retries).and_return(elbv2)

      expect { aws.alb_addresses(name: 'nonexistent-alb') }.to raise_error("Load balancer 'nonexistent-alb' not found")
    end

    it "should support querying ALBs in a different region" do
      elbv2_west = Aws::ElasticLoadBalancingV2::Client.new(stub_responses: true)
      lb_data = elbv2_west.stub_data(:describe_load_balancers, load_balancers: [{
        load_balancer_name: 'west-alb',
        load_balancer_arn: 'arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/west-alb/50dc6c495c0c9188',
        availability_zones: [
          {
            zone_name: 'us-west-2a',
            subnet_id: 'subnet-west1',
            load_balancer_addresses: [
              { ip_address: '10.1.1.5' }
            ]
          }
        ]
      }])

      elbv2_west.stub_responses(:describe_load_balancers, lb_data)
      allow(aws).to receive(:elbv2_with_retries).with(region: 'us-west-2').and_return(elbv2_west)

      addresses = aws.alb_addresses(name: 'west-alb', region: 'us-west-2')
      expect(addresses.count).to eq(1)
      expect(addresses[0].ip_address).to eq('10.1.1.5')
      expect(addresses[0].availability_zone).to eq('us-west-2a')
      expect(addresses[0].subnet_id).to eq('subnet-west1')
    end
  end
end
