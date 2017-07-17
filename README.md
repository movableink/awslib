# MovableInk::AWS gem

## Building

`gem build MovableInkAWS.gemspec`

## Installing

`gem install ./MovableInkAWS-<VERSION>.gem`

## Using

```ruby
require 'movable_ink/aws'

miaws = MovableInk::AWS.new

miaws.datacenter

miaws.instance_ip_addresses_by_role(role: 'varnish').map { |m| "http://#{m}:8080" }

...
```
