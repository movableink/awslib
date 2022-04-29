require_relative 'aws/errors'
require_relative 'aws/metadata'
require_relative 'aws/ec2'
require_relative 'aws/sns'
require_relative 'aws/autoscaling'
require_relative 'aws/route53'
require_relative 'aws/ssm'
require_relative 'aws/athena'
require_relative 'aws/s3'
require_relative 'aws/iam'
require_relative 'aws/eks'
require_relative 'aws/elasticache'
require_relative 'aws/api_gateway'
require_relative 'consul/consul'
require 'aws-sdk-cloudwatch'


module MovableInk
  class AWS
    include Metadata
    include EC2
    include SNS
    include Autoscaling
    include Route53
    include SSM
    include Athena
    include S3
    include ElastiCache
    include ApiGateway
    include EKS

    class << self
      def regions
        {
          'iad' => 'us-east-1',
          'rld' => 'us-west-2',
          'dub' => 'eu-west-1',
          'ord' => 'us-east-2',
          'fra' => 'eu-central-1'
        }
      end
    end

    def initialize(
      ipv4: nil,
      environment: nil,
      global_service: nil,
      instance_id: nil,
      availability_zone: nil
    )
      @mi_env = environment
      @ipv4 = ipv4
      @instance_id = instance_id
      @availability_zone = availability_zone

      if global_service
        @availability_zone = 'us-east-1a'
        @instance_id = global_service
        @ipv4 = global_service
      end
    end

    def run_with_backoff(quiet: false, tries: 9)
      tries.times do |num|
        begin
          return yield
        rescue Aws::EC2::Errors::RequestLimitExceeded,
               Aws::EC2::Errors::ResourceAlreadyAssociated,
               Aws::EC2::Errors::Unavailable,
               Aws::EC2::Errors::InternalError,
               Aws::EC2::Errors::Http503Error,
               Aws::EKS::Errors::TooManyRequestsException,
               Aws::SNS::Errors::ThrottledException,
               Aws::SNS::Errors::Throttling,
               Aws::AutoScaling::Errors::Throttling,
               Aws::AutoScaling::Errors::ThrottledException,
               Aws::S3::Errors::SlowDown,
               Aws::Route53::Errors::Throttling,
               Aws::Route53::Errors::ThrottlingException,
               Aws::Route53::Errors::PriorRequestNotComplete,
               Aws::Route53::Errors::ServiceUnavailable,
               Aws::SSM::Errors::TooManyUpdates,
               Aws::SSM::Errors::ThrottlingException,
               Aws::SSM::Errors::InternalServerError,
               Aws::SSM::Errors::Http503Error,
               Aws::SSM::Errors::Http502Error,
               Aws::Athena::Errors::ThrottlingException,
               MovableInk::AWS::Errors::NoEnvironmentTagError
          sleep_time = (num+1)**2 + rand(10)
          if quiet
            (num >= tries - 1) ? notify_and_sleep(sleep_time, $!.class) : sleep(sleep_time)
          else
            notify_and_sleep(sleep_time, $!.class)
          end
        rescue Aws::Errors::ServiceError => e
          message = "#{e.class}: #{e.message}\nFrom #{$0}\n```\n#{e.backtrace.first(3).join("\n").gsub("`","'")}\n```"
          notify_slack(subject: 'Unhandled AWS API Error', message: message)
          puts message
          raise MovableInk::AWS::Errors::ServiceError
        end
      end
      message = "From: #{$0}\n```\n#{Thread.current.backtrace.first(3).join("\n").gsub("`","'")}\n```"
      notify_slack(subject: "AWS API failed after #{tries} attempts", message: message)
      puts message
      raise MovableInk::AWS::Errors::FailedWithBackoff
    end

    def regions
      self.class.regions
    end

    def my_region
      @my_region ||= if ENV['AWS_REGION'].nil?
        availability_zone.chop
      else
        ENV['AWS_REGION']
      end
    end

    def datacenter(region: my_region)
      regions.key(region)
    end
  end
end
