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
        instance_tags
          .detect { |tag| tag.key == 'mi:env' }
          .value
      rescue NoMethodError
        raise MovableInk::AWS::Errors::NoEnvironmentTagError
      end

      def thopter_filter
        [{
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
        }]
      end

      def thopter_instance
        @thopter_instance ||= load_all_instances('us-east-1', filter: thopter_filter)
      end

      def all_instances(region: my_region, no_filter: false)
        @all_instances ||= {}
        @all_instances[region] ||= load_all_instances(region, no_filter: no_filter)
      end

      def default_filter
        [{
          name: 'instance-state-name',
          values: ['running']
        },
        {
          name: 'tag:mi:env',
          values: [mi_env]
        }]
      end

      def load_all_instances(region, no_filter: false, filter: nil)
        filters = no_filter ? nil : (filter || default_filter)

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

      def instance_tags
        @instance_tags ||= run_with_backoff(quiet: true) do
          ec2.describe_tags({
            filters: [{ name: 'resource-id', values: [instance_id] } ]
          }).tags
        end
      end

      def private_ipv4
        @ipv4 ||= begin
          ipv4 = `ec2metadata --local-ipv4 2>/dev/null`.chomp
          raise(MovableInk::AWS::Errors::EC2Required) if ipv4.empty?
          ipv4
        end
      end

      def me
        @me ||= all_instances.select{|instance| instance.instance_id == instance_id}
      end

      def instances(role:, exclude_roles: [], region: my_region, availability_zone: nil, exact_match: false)
        instances = all_instances(region: region).select { |instance|
          instance.tags.select{ |tag| tag.key == 'mi:roles' }.detect { |tag|
            roles = tag.value.split(/\s*,\s*/)
            if exact_match
              roles == [role]
            else
              exclude_roles.push('decommissioned')
              roles.include?(role) && !roles.any? { |role| exclude_roles.include?(role) }
            end
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

      def instance_ip_addresses_by_role(role:, exclude_roles: [], region: my_region, availability_zone: nil, exact_match: false)
        private_ip_addresses(instances(role: role, exclude_roles: exclude_roles, region: region, availability_zone: availability_zone, exact_match: exact_match))
      end

      def instance_ip_addresses_by_role_ordered(role:, exclude_roles: [], region: my_region, exact_match: false)
        instances = instances(role: role, exclude_roles: exclude_roles, region: region, exact_match: exact_match)
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

      def elastic_ips
        @all_elastic_ips ||= run_with_backoff do
          ec2.describe_addresses.addresses
        end
      end

      def unassigned_elastic_ips
        @unassigned_elastic_ips ||= elastic_ips.select { |address| address.association_id.nil? }
      end

      def available_elastic_ips(role:)
        unassigned_elastic_ips.select { |address| address.tags.detect { |t| t.key == 'mi:roles' && t.value == role } }
      end

      def assign_ip_address(role:)
        run_with_backoff do
          ec2.associate_address({
            instance_id: instance_id,
            allocation_id: available_elastic_ips(role: role).sample.allocation_id
          })
        end
      end
    end
  end
end
