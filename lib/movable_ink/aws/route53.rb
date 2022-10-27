require 'aws-sdk-route53'

module MovableInk
  class AWS
    module Route53
      def route53(client = nil)
        @route53_client ||= (client) ? client : Aws::Route53::Client.new(region: 'us-east-1')
      end

      def resource_record_sets(hosted_zone_id, client = nil)
        @resource_record_sets ||= {}
        @resource_record_sets[hosted_zone_id] ||= list_all_r53_resource_record_sets(hosted_zone_id, client)
      end

      def get_resource_record_sets_by_instance_name(zone, instance_name, client = nil)
        resource_record_sets(zone, client).select{|rrs| rrs.set_identifier == instance_name}.map(&:to_h)
      end

      def delete_resource_record_sets(zone, instance_name, client = nil, expected_errors = [])
        resource_record_sets = get_resource_record_sets_by_instance_name(zone, instance_name, client)
        return if resource_record_sets.empty?

        change_batch = {
          "changes": resource_record_sets.map { |resource_record_set|
            {
              "action": 'DELETE',
              "resource_record_set": resource_record_set
            }
          }
        }

        run_with_backoff(expected_errors: expected_errors) do
          route53(client).change_resource_record_sets({change_batch: change_batch, hosted_zone_id: zone})
        end
      end

      def list_all_r53_resource_record_sets(hosted_zone_id, client = nil)
        resp = run_with_backoff { route53(client).list_resource_record_sets({ hosted_zone_id: hosted_zone_id }) }
        rrs = resp.resource_record_sets

        # https://docs.aws.amazon.com/Route53/latest/APIReference/API_ListResourceRecordSets.html
        while resp.is_truncated
          resp = run_with_backoff { route53(client).list_resource_record_sets({
            hosted_zone_id: hosted_zone_id,
            start_record_name: resp.next_record_name,
            start_record_type: resp.next_record_type,
            start_record_identifier: resp.next_record_identifier
          }) }
          rrs += resp.resource_record_sets
        end
        rrs
      end

      def list_health_checks(client = nil)
        run_with_backoff do
          route53(client).list_health_checks().flat_map(&:health_checks)
        end
      end

      def get_health_check_tags(health_check_id, client = nil)
        run_with_backoff do
          route53(client).list_tags_for_resource({
            resource_type: 'healthcheck',
            resource_id: health_check_id
          }).resource_tag_set.tags
        end
      end

      def find_health_check_by_tag(key, value, client = nil)
        list_health_checks(client).detect do |health_check|
          get_health_check_tags(health_check.id, client).detect { |tag| tag.key == key && tag.value.include?(value) }
        end
      end

      def list_hosted_zones(client: nil)
        resp = run_with_backoff { route53(client).list_hosted_zones() }
        zones = resp.hosted_zones

        # https://docs.aws.amazon.com/Route53/latest/APIReference/API_ListHostedZones.html
        while resp.is_truncated
          resp = run_with_backoff { route53(client).list_hosted_zones({marker: resp.next_marker}) }
          zones += resp.hosted_zones
        end
        zones
      end
    end
  end
end
