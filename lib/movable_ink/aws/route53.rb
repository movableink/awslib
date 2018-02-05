module MovableInk
  class AWS
    module Route53
      def route53
        @route53_client ||= Aws::Route53::Client.new(region: 'us-east-1')
      end

      def elastic_ips
        @all_elastic_ips ||= load_all_elastic_ips
      end

      def load_all_elastic_ips
        run_with_backoff do
          ec2.describe_addresses.flat_map(&:addresses)
        end
      end

      def unassigned_elastic_ips
        @unassigned_elastic_ips ||= elastic_ips.select { |address| address.association_id.nil? }
      end

      def reserved_elastic_ips
        @reserved_elastic_ips ||= s3.get_object({bucket: 'movableink-chef', key: 'reserved_ips.json'}).body
                                    .map { |line| JSON.parse(line) }
      end

      def available_elastic_ips(role:)
        reserved_elastic_ips.select do |ip|
          ip["datacenter"] == datacenter &&
          ip["role"] == role &&
          unassigned_elastic_ips.map(&:allocation_id).include?(ip["allocation_id"])
        end
      end

      def assign_ip_address(role:)
        run_with_backoff do
          ec2.associate_address({
            instance_id: instance_id,
            allocation_id: available_elastic_ips(role: role).sample["allocation_id"]
          })
        end
      end

      def resource_record_sets(hosted_zone_id)
        @resource_record_sets ||= {}
        @resource_record_sets[hosted_zone_id] ||= list_all_r53_resource_record_sets(hosted_zone_id)
      end

      def list_all_r53_resource_record_sets(hosted_zone_id)
        run_with_backoff do
          route53.list_resource_record_sets({
            hosted_zone_id: hosted_zone_id
          }).flat_map(&:resource_record_sets)
        end
      end
    end
  end
end
