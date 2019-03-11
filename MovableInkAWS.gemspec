$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "movable_ink/version"

Gem::Specification.new do |s|
  s.name          = 'MovableInkAWS'
  s.version       = MovableInk::AWS::VERSION
  s.summary       = 'AWS Utility methods for MovableInk'
  s.description   = 'AWS Utility methods for MovableInk'
  s.authors       = ['Matt Chesler']
  s.email         = 'mchesler@movableink.com'

  s.add_runtime_dependency 'aws-sdk',  '2.11.233'

  all_files  = `git ls-files`.split("\n")
  test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.files         = all_files - test_files
  s.test_files    = test_files
  s.require_paths = ["lib"]
end
