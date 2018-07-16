require 'aws-sdk'

require_relative 'aws/errors'
require_relative 'aws/ec2'
require_relative 'aws/sns'
require_relative 'aws/autoscaling'
require_relative 'aws/route53'
require_relative 'aws/ssm'
require_relative 'aws/athena'
require_relative 'aws/s3'

module MovableInk
  class AWS
    include EC2
    include SNS
    include Autoscaling
    include Route53
    include SSM
    include Athena
    include S3

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

    def initialize(environment: nil, global_service: nil)
      @mi_env = environment
      if global_service
        @availability_zone = 'us-east-1a'
        @instance_id = global_service
      end
    end

    def run_with_backoff(quiet: false)
      9.times do |num|
        begin
          return yield
        rescue Aws::EC2::Errors::RequestLimitExceeded,
               Aws::SNS::Errors::ThrottledException,
               Aws::AutoScaling::Errors::ThrottledException,
               Aws::S3::Errors::SlowDown,
               Aws::Route53::Errors::ThrottlingException,
               Aws::Route53::Errors::PriorRequestNotComplete,
               Aws::SSM::Errors::TooManyUpdates,
               Aws::Athena::Errors::ThrottlingException,
               MovableInk::AWS::Errors::NoEnvironmentTagError
          sleep_time = (num+1)**2 + rand(10)
          if quiet
            (num >=8) ? notify_and_sleep(sleep_time, $!.class) : sleep(sleep_time)
          else
            notify_and_sleep(sleep_time, $!.class)
          end
        rescue Aws::Errors::ServiceError => e
          message = "#{e.class}: #{e.message}\nFrom `#{e.backtrace.last.gsub("`","'")}`"
          notify_slack(subject: 'Unhandled AWS API Error',
                       message: message)
          puts message
          raise MovableInk::AWS::Errors::ServiceError
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
  end
end
