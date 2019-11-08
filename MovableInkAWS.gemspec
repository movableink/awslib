$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "movable_ink/version"

Gem::Specification.new do |s|
  s.name          = 'MovableInkAWS'
  s.version       = MovableInk::AWS::VERSION
  s.summary       = 'AWS Utility methods for MovableInk'
  s.description   = 'AWS Utility methods for MovableInk'
  s.authors       = ['Matt Chesler']
  s.email         = 'mchesler@movableink.com'

  s.add_runtime_dependency 'aws-sdk-core', '~> 3'
  s.add_runtime_dependency 'aws-sdk-athena', '~> 1'
  s.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1'
  s.add_runtime_dependency 'aws-sdk-ec2', '~> 1'
  s.add_runtime_dependency 'aws-sdk-elasticache', '~> 1'
  s.add_runtime_dependency 'aws-sdk-route53', '~> 1'
  s.add_runtime_dependency 'aws-sdk-s3', '~> 1'
  s.add_runtime_dependency 'aws-sdk-sns', '~> 1'
  s.add_runtime_dependency 'aws-sdk-ssm', '~> 1'
  s.add_runtime_dependency 'aws-sigv4', '~> 1.1'
  s.add_runtime_dependency 'httparty',  '0.16.3'

  all_files  = `git ls-files`.split("\n")
  test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.files         = all_files - test_files
  s.test_files    = test_files
  s.require_paths = ["lib"]
end
