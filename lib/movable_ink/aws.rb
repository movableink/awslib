require 'aws-sdk'

module MovableInk
  class AWS
    def initialize
      raise "Can only be used within EC2" unless instance_id
    end

    def run_with_backoff
      9.times do |num|
        begin
          return yield
        rescue Aws::EC2::Errors::RequestLimitExceeded
          notify_and_sleep(num**2 + rand(10))
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

    def availability_zone
      @availability_zone ||= `ec2metadata --availability-zone`.chomp rescue nil
    end

    def region
      @region ||= availability_zone.chop
    end

    def instance_id
      @instance_id ||= `ec2metadata --instance-id`.chomp rescue nil
    end

    def datacenter
      regions.key(region)
    end

    def ec2
      @ec2_client ||= Aws::EC2::Client.new(region: region)
    end

    def sns
      @sns_client ||= Aws::SNS::Client.new(region: region)
    end

    def autoscaling
      @autoscaling_client ||= Aws::Autoscaling::Client.new(region: region)
    end

    def s3
      @s3_client ||= Aws::S3::Client.new(region: 'us-east-1')
    end

    def sns_slack_topic_arn
      sns.list_topics.topics.select {|topic| topic.topic_arn.include? "slack-aws-alerts"}
          .first.topic_arn
    end

    def notify_and_sleep(seconds)
      message = "Instance Id #{instance_id} has been throttled in #{region}."
      sns.publish(:topic_arn => sns_slack_topic_arn, :message => message, :subject => "API Throttled")
      puts "Throttled by AWS.  Sleeping #{seconds} seconds."
      sleep seconds
    end

    def notify_nsq_can_not_be_drained
      message = "Unable to drain nsq on instance #{instance_id}"
      sns.publish(:topic_arn => sns_slack_topic_arn, :message => message, :subject => "Nsq not drained")
    end

    def mi_env
      @mi_env ||= load_mi_env
    end

    def load_mi_env
      run_with_backoff do
        ec2.describe_tags({:filters =>
              [{:name =>'resource-id',
                :values => [instance_id]
              }]
            })
           .tags
           .detect { |tag| tag.key == 'mi:env' }
           .value
      end
    end

    def thopter_instance
      @thopter_instance ||= load_thopter_instance
    end

    def load_thopter_instance
      run_with_backoff do
        Aws::EC2::Client.new(region: 'us-east-1')
          .describe_instances(filters: [
            {
              name: 'tag:mi:roles',
              values: ['*thopter*']
            },
            {
              name: 'tag:mi:env',
              values: [mi_env]
            },
            {
              name: 'instance-state-name',
              values: ['running']
            }
          ])
          .reservations
          .map { |r| r.instances }
          .flatten
      end
    end

    def all_instances
      @all_instances ||= load_all_instances
    end

    def load_all_instances
      run_with_backoff do
        resp = ec2.describe_instances(filters: [{
                                        name: 'instance-state-name',
                                        values: ['running']
                                      },
                                      {
                                        name: 'tag:mi:env',
                                        values: [mi_env]
                                      }
                                    ])
        reservations = resp.reservations
        while (!resp.last_page?) do
          resp = resp.next_page
          reservations += resp.reservations
        end
        reservations.map { |r| r.instances }.flatten
      end
    end

    def instances(role:, availability_zone: nil)
      role_pattern = mi_env == 'production' ? "^#{role}$" : "^*#{role}*$"
      role_pattern = role_pattern.gsub('**','*').gsub('*','.*')
      instances = all_instances.select { |instance|
        instance.tags.detect { |tag|
          tag.key == 'mi:roles'&&
            Regexp.new(role_pattern).match(tag.value) &&
            !tag.value.include?('decommissioned')
        }
      }
      if availability_zone
        instances.select { |instance|
          instance.placement.availability_zone == availability_zone
        }
      else
        instances
      end
    end

    def thopter
      private_ip_addresses(thopter_instance).first
    end

    def statsd_host
      instance_ip_addresses_by_role(role: 'statsd', availability_zone: availability_zone).sample
    end

    def private_ip_addresses(instances)
      instances.map {|instance| instance.private_ip_address}
    end

    def instance_ip_addresses_by_role(role:, availability_zone: nil)
      private_ip_addresses(instances(role: role, availability_zone: availability_zone))
    end

    def instance_ip_addresses_by_role_ordered(role:)
      instances = instances(role: role)
      instances_in_my_az = instances.select { |instance| instance.placement.availability_zone == availability_zone }
      ordered_instances = instances_in_my_az + (instances - instances_in_my_az)
      private_ip_addresses(ordered_instances)
    end

    def redis_by_role(role, port)
      instance_ip_addresses_by_role(role: role)
        .inject([]) { |redii, instance|
          redii.push({"host" => instance, "port" => port})
        }
    end

    def mark_me_as_unhealthy
      run_with_backoff do
        autoscaling.set_instance_health({
          health_status: "Unhealthy",
          instance_id: instance_id,
          should_respect_grace_period: false
        })
      end
    end

    def mark_me_as_healthy(role:)
      run_with_backoff do
        ec2.create_tags({
          resources: [instance_id],
          tags: [
            {
              key: "mi:roles",
              value: role
            }
          ]
        })
      end
    end

    def delete_role_tag(role:)
      run_with_backoff do
        ec2.delete_tags({
          resources: [instance_id],
          tags: [
            {
              key: "mi:roles",
              value: role
            }
          ]
        })
      end
    end

    def complete_lifecycle_action(hook_name:, group_name:, token:)
      run_with_backoff do
        autoscaling.complete_lifecycle_action({
          lifecycle_hook_name:     hook_name,
          auto_scaling_group_name: group_name,
          lifecycle_action_token:  token,
          lifecycle_action_result: 'CONTINUE'
        })
      end
    end

    def record_lifecycle_action_heartbeat(hook_name:, group_name:)
      run_with_backoff do
        autoscaling.record_lifecycle_action_heartbeat({
          lifecycle_hook_name:     hook_name,
          auto_scaling_group_name: group_name
        })
      end
    end

    def elastic_ips
      @all_elastic_ips ||= load_all_elastic_ips
    end

    def load_all_elastic_ips
      run_with_backoff do
        resp = ec2.describe_addresses
        addresses = resp.addresses
        while (!resp.last_page?) do
          resp = resp.next_page
          addresses += resp.addresses
        end
        addresses
      end
    end

    def unassigned_elastic_ips
      @unassigned_elastic_ips ||= elastic_ips.select { |address| address.association_id.nil? }
    end

    def available_elastic_ips
      @available_elastic_ips ||= s3.get_object({bucket: 'movableink-chef', key: 'reserved_ips.json'}).body
                                  .map { |line| JSON.parse(line) }
                                  .select { |ip| ip["datacenter"] == datacenter && ip["role"] == 'cors_proxy'}
                                  .select { |ip| unassigned_elastic_ips.map(&:allocation_id).include?(ip["allocation_id"]) }
    end

    def assign_ip_address
      run_with_backoff do
        ec2.associate_address({
          instance_id: instance_id,
          allocation_id: available_elastic_ips.sample["allocation_id"]
        })
      end
    end
  end
end
