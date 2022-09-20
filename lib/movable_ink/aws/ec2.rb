require 'aws-sdk-ec2'
require 'diplomat'

module MovableInk
  class AWS
    module EC2
      def ec2(region: my_region, client: nil)
        @ec2_client ||= {}
        @ec2_client[region] ||= (client) ? client : Aws::EC2::Client.new(region: region)
      end

      def mi_env_cache_file_path
        '/etc/movableink/environments.json'
      end

      def mi_env
        @mi_env ||= if File.exist?(mi_env_cache_file_path)
          environments = JSON.parse(File.read(mi_env_cache_file_path))
          environments[my_region] || load_mi_env
        else
          load_mi_env
        end
      end

      def load_mi_env
        instance_tags
          .detect { |tag| tag.key == 'mi:env' }
          .value
      rescue NoMethodError
        raise MovableInk::AWS::Errors::NoEnvironmentTagError
      end

      def thopter_instance
        @thopter_instance ||= all_instances(region: 'us-east-1').select do |instance|
          instance.tags.select{ |tag| tag.key == 'mi:roles' }.detect do |tag|
            tag.value.include?('thopter')
          end
        end
      end

      def all_instances(region: my_region, no_filter: false, client: nil)
        @all_instances ||= {}
        @all_instances[region] ||= load_all_instances(region, no_filter: no_filter, client: client)
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

      def load_all_instances(region, no_filter: false, filter: nil, client: nil)
        filters = no_filter ? nil : (filter || default_filter)

        run_with_backoff do
          ec2(region: region, client: client).describe_instances(filters: filters).flat_map do |resp|
            resp.reservations.flat_map(&:instances)
          end
        end
      end

      def instance_tags
        @instance_tags ||= run_with_backoff(quiet: true) do
          ec2.describe_tags({
            filters: [{ name: 'resource-id', values: [instance_id] } ]
          }).tags
        end
      end

      def me
        @me ||= all_instances.select{|instance| instance.instance_id == instance_id}.first rescue nil
      end

      def instances_with_ec2_discovery(role:, exclude_roles: [], region: my_region, availability_zone: nil, exact_match: false, use_cache: true)
        roles = role.split(/\s*,\s*/)
        if use_cache == false
          filter = default_filter.push({
            name: 'tag:mi:roles',
            values: roles
          })
          instances = load_all_instances(region, filter: filter)
        else
          instances = all_instances(region: region).select { |instance|
            instance.tags.select{ |tag| tag.key == 'mi:roles' }.detect { |tag|
              tag_roles = tag.value.split(/\s*,\s*/)
              if exact_match
                tag_roles == roles
              else
                exclude_roles.push('decommissioned')
                tag_roles.any? { |tag_role| roles.include?(tag_role) } && !tag_roles.any? { |role| exclude_roles.include?(role) }
              end
            }
          }
        end

        if availability_zone
          instances.select { |instance|
            instance.placement.availability_zone == availability_zone
          }
        else
          instances
        end
      end

      def instances_with_consul_discovery(role:, region: my_region, availability_zone: nil)
        if role == nil || role == ''
          raise MovableInk::AWS::Errors::RoleNameRequiredError
        end

        consul_service_options = {
          dc: datacenter(region: region),
          stale: true,
          cached: true,
          passing: true,
        }
        consul_service_options[:node_meta] = "availability_zone:#{availability_zone}" unless availability_zone.nil?

        # We replace underscores with dashes in the role name in order to comply with
        # consul service naming conventions while still retaining the role name we use
        # within MI configuration
        Diplomat::Health.service(role.gsub('_', '-'), consul_service_options).map { |endpoint|
          if endpoint.Node.dig('Meta', 'external-source') == 'kubernetes'
            map_k8s_consul_endpoint(endpoint, role)
          else
            map_ec2_consul_endpoint(endpoint)
          end
        }
      end

      def map_k8s_consul_endpoint(endpoint, role)
        OpenStruct.new ({
          private_ip_address: endpoint.Service.dig('Address'),
          instance_id: nil,
          tags: [
            {
              key: 'Name',
              value: endpoint.Service.dig('ID')
            },
            {
              key: 'mi:roles',
              value: role
            },
            {
              key: 'mi:monitoring_roles',
              value: role
            }
          ],
          placement: { availability_zone: nil }
        })
      end

      def map_ec2_consul_endpoint(endpoint)
        OpenStruct.new ({
          private_ip_address: endpoint.Node.dig('Address'),
          instance_id: endpoint.Node.dig('Meta', 'instance_id'),
          tags: [
            {
              key: 'Name',
              value: endpoint.Node.dig('Node')
            },
            {
              key: 'mi:roles',
              value: endpoint.Node.dig('Meta', 'mi_roles')
            },
            {
              key: 'mi:monitoring_roles',
              value: endpoint.Node.dig('Meta', 'mi_monitoring_roles')
            }
          ],
          placement: {
            availability_zone: endpoint.Node.dig('Meta', 'availability_zone')
          }
        })
      end

      def instances(role:, exclude_roles: [], region: my_region, availability_zone: nil, exact_match: false, use_cache: true, discovery_type: 'ec2')
        if discovery_type == 'ec2'
          instances_with_ec2_discovery(role: role, exclude_roles: exclude_roles, region: region, availability_zone: availability_zone, exact_match: exact_match, use_cache: use_cache)
        elsif discovery_type == 'consul'
          instances_with_consul_discovery(role: role, region: region, availability_zone: availability_zone)
        else
          raise MovableInk::AWS::Errors::InvalidDiscoveryTypeError
        end
      end

      def thopter
        private_ip_addresses(thopter_instance).first
      end

      def statsd_host
        instance_ip_addresses_by_role(role: 'statsd', availability_zone: availability_zone, use_cache: false).sample
      end

      def private_ip_addresses(instances)
        instances.map(&:private_ip_address)
      end

      def instance_ip_addresses_by_role(role:, exclude_roles: [], region: my_region, availability_zone: nil, exact_match: false, use_cache: true)
        private_ip_addresses(instances(role: role, exclude_roles: exclude_roles, region: region, availability_zone: availability_zone, exact_match: exact_match, use_cache: use_cache))
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
