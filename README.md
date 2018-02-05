# MovableInk::AWS gem

## Building

`gem build MovableInkAWS.gemspec`

## "Publishing"

Travis will automatically publish your gem to rubygems.org when you tag a release and push to origin.
Before you do so, ensure that the version in `lib/movable_ink/version.rb` matches the tag you're creating,
e.g. Version `1.0.0` in `lib/movable_ink/version.rb` should be tagged as `v1.0.0`

## Installing

### From rubygems.org

`gem install MovableInkAWS -v <VERSION>`

### Locally

`gem install MovableInkAWS-<VERSION>.gem`

## Using

```ruby
require 'movable_ink/aws'

miaws = MovableInk::AWS.new

miaws.datacenter

miaws.instance_ip_addresses_by_role(role: 'varnish').map { |m| "http://#{m}:8080" }

...
```
