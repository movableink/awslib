$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "movable_ink/version"

Gem::Specification.new do |s|
  s.name          = 'MovableInkAWS'
  s.version       = MovableInk::AWS::VERSION
  s.summary       = 'AWS Utility methods for MovableInk'
  s.description   = 'AWS Utility methods for MovableInk'
  s.authors       = ['MI SRE']
  s.email         = 'devops@movableink.com'

  s.required_ruby_version = '>= 2.6.0'

  s.add_runtime_dependency 'aws-sdk-core', '~> 3'
  s.add_runtime_dependency 'aws-sdk-athena', '~> 1'
  s.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1'
  s.add_runtime_dependency 'aws-sdk-cloudwatch', '~> 1'
  s.add_runtime_dependency 'aws-sdk-ec2', '~> 1'
  s.add_runtime_dependency 'aws-sdk-eks', '~> 1'
  s.add_runtime_dependency 'aws-sdk-elasticache', '~> 1'
  s.add_runtime_dependency 'aws-sdk-iam', '~> 1'
  s.add_runtime_dependency 'aws-sdk-lambda', '~> 1'
  s.add_runtime_dependency 'aws-sdk-rds', '~> 1'
  s.add_runtime_dependency 'aws-sdk-route53', '~> 1'
  s.add_runtime_dependency 'aws-sdk-s3', '~> 1'
  s.add_runtime_dependency 'aws-sdk-sns', '~> 1'
  s.add_runtime_dependency 'aws-sdk-ssm', '~> 1'
  s.add_runtime_dependency 'aws-sigv4', '~> 1'
  s.add_runtime_dependency 'httparty',  '0.23.1'
  s.add_runtime_dependency 'diplomat',  '2.6.4'

  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.0.0')
    s.add_runtime_dependency 'faraday',  '~> 2.8.1'
    s.add_runtime_dependency 'faraday-net_http', '~> 3.0.2'
    s.add_runtime_dependency 'multi_xml', '~> 0.6.0'
  else
    s.add_runtime_dependency 'faraday',  '~> 2'
  end

  all_files  = `git ls-files`.split("\n")
  test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.files         = all_files - test_files
  s.test_files    = test_files
  s.require_paths = ["lib"]
end
