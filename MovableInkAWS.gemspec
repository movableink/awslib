Gem::Specification.new do |s|
  s.name        = 'MovableInkAWS'
  s.version     = '0.0.1'
  s.summary     = 'AWS Utility methods for MovableInk'
  s.description = 'AWS Utility methods for MovableInk'
  s.authors     = ['Matt Chesler']
  s.email       = 'mchesler@movableink.com'
  s.files       = ['lib/movable_ink/aws.rb']
  s.add_runtime_dependency 'aws-sdk', '~> 2'
end
