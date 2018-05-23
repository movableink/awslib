require 'aws-sdk'

require_relative 'aws/errors'
require_relative 'aws/ec2'
require_relative 'aws/sns'
require_relative 'aws/autoscaling'
require_relative 'aws/route53'
require_relative 'aws/ssm'

module MovableInk
  class AWS
    include EC2
    include SNS
    include Autoscaling
    include Route53
    include SSM

    class << self
      def regions
        {
          'iad' => 'us-east-1',
          'rld' => 'us-west-2',
          'dub' => 'eu-west-1',
          'ord' => 'us-east-2'
        }
      end
    end

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
               Aws::Route53::Errors::ThrottlingException,
               Aws::Route53::Errors::ServiceError,
               Aws::SSM::Errors::TooManyUpdates,
               Aws::Route53::Errors::InvalidChangeBatch,
               Aws::Route53::Errors::InvalidInput
          notify_and_sleep((num+1)**2 + rand(10), $!.class)
        end
      end
      raise MovableInk::AWS::Errors::FailedWithBackoff
    end

    def regions
      self.class.regions
    end

    def availability_zone
      @availability_zone ||= begin
        az = `ec2metadata --availability-zone 2>/dev/null`.chomp
        raise(MovableInk::AWS::Errors::EC2Required) if az.empty?
        az
      end
    end

    def my_region
      @my_region ||= availability_zone.chop
    end

    def datacenter(region: my_region)
      regions.key(region)
    end

    def s3
      @s3_client ||= Aws::S3::Client.new(region: 'us-east-1')
    end
  end
end
