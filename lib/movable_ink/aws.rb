require 'aws-sdk'

require_relative 'aws/errors'
require_relative 'aws/ec2'
require_relative 'aws/sns'
require_relative 'aws/autoscaling'
require_relative 'aws/route53'

module MovableInk
  class AWS
    include EC2
    include SNS
    include Autoscaling
    include Route53

    def initialize(environment: nil)
      @mi_env = environment
    end

    def run_with_backoff
      9.times do |num|
        begin
          return yield
        rescue Aws::EC2::Errors::RequestLimitExceeded,
               Aws::SNS::Errors::ThrottledException,
               Aws::AutoScaling::Errors::ThrottledException,
               Aws::S3::Errors::SlowDown,
               Aws::Route53::Errors::ThrottlingException
          notify_and_sleep(num**2 + rand(10), $!.class)
        end
      end
      nil
    end

    def regions
      {
        'iad' => 'us-east-1',
        'rld' => 'us-west-2',
        'dub' => 'eu-west-1',
        'ord' => 'us-east-2'
      }
    end

    def ec2_required
      raise("Can only be used in EC2")
    end

    def availability_zone
      @availability_zone ||= `ec2metadata --availability-zone`.chomp rescue ec2_required
    end

    def my_region
      @my_region ||= availability_zone.chop
    end

    def instance_id
      @instance_id ||= `ec2metadata --instance-id`.chomp rescue ec2_required
    end

    def datacenter(region: my_region)
      regions.key(region)
    end

    def s3
      @s3_client ||= Aws::S3::Client.new(region: 'us-east-1')
    end
  end
end
