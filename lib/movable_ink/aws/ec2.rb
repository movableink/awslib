module MovableInk
  class AWS
    module EC2
      def ec2(region: my_region)
        @ec2_client ||= {}
        @ec2_client[region] ||= Aws::EC2::Client.new(region: region)
      end

      def mi_env
        @mi_env ||= load_mi_env
      end

      def load_mi_env
        run_with_backoff do
          ec2.describe_tags(filters: [
                {
                  name: 'resource-id',
                  values: [instance_id]
                }
              ])
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
          ec2(region: 'us-east-1').describe_instances(filters: [
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
          .flat_map(&:instances)
        end
      end

      def all_instances(region: my_region, no_filter: false)
        @all_instances ||= {}
        @all_instances[region] ||= load_all_instances(region, no_filter: no_filter)
      end

      def load_all_instances(region, no_filter: false)
        filters = if no_filter
          nil
        else
          [{
            name: 'instance-state-name',
            values: ['running']
          },
          {
            name: 'tag:mi:env',
            values: [mi_env]
          }]
        end
        run_with_backoff do
          ec2(region: region).describe_instances(filters: filters).flat_map do |resp|
            resp.reservations.flat_map(&:instances)
          end
        end
      end

      def instance_id
        @instance_id ||= begin
          az = `ec2metadata --instance-id 2>/dev/null`.chomp
          raise(MovableInk::AWS::Errors::EC2Required) if az.empty?
          az
        end
      end

      def me
        @me || = all_instances.select(|instance| instance.instance_id == instance_id)
      end

      def instances(role:, region: my_region, availability_zone: nil)
        role_pattern = mi_env == 'production' ? "^#{role}$" : "^*#{role}*$"
        role_pattern = role_pattern.gsub('**','*').gsub('*','.*')
        instances = all_instances(region: region).select { |instance|
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
        instances.map(&:private_ip_address)
      end

      def instance_ip_addresses_by_role(role:, availability_zone: nil)
        private_ip_addresses(instances(role: role, availability_zone: availability_zone))
      end

      def instance_ip_addresses_by_role_ordered(role:)
        instances = instances(role: role)
        instances_in_my_az = instances.select { |instance| instance.placement.availability_zone == availability_zone }
        ordered_instances = instances_in_my_az.shuffle + (instances - instances_in_my_az).shuffle
        private_ip_addresses(ordered_instances)
      end

      def redis_by_role(role, port)
        instance_ip_addresses_by_role(role: role)
          .shuffle
          .inject([]) { |redii, instance|
            redii.push({"host" => instance, "port" => port})
          }
      end
    end
  end
end
