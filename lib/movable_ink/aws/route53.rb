require 'aws-sdk-route53'

module MovableInk
  class AWS
    module Route53
      def route53
        @route53_client ||= Aws::Route53::Client.new(region: 'us-east-1')
      end

      def resource_record_sets(hosted_zone_id)
        @resource_record_sets ||= {}
        @resource_record_sets[hosted_zone_id] ||= list_all_r53_resource_record_sets(hosted_zone_id)
      end

      def get_resource_record_sets_by_instance_name(zone, instance_name)
        resource_record_sets(zone).select{|rrs| rrs.set_identifier == instance_name}.first.to_h
      end

      def delete_resource_record_sets(zone, instance_name)
        resource_record_set = get_resource_record_sets_by_instance_name(zone, instance_name)
        return if resource_record_set.empty?

        change_batch = {
          "changes": [{
            "action": 'DELETE',
            "resource_record_set": resource_record_set
          }]
        }

        run_with_backoff do
          route53.change_resource_record_sets({change_batch: change_batch, hosted_zone_id: zone})
        end
      end

      def list_all_r53_resource_record_sets(hosted_zone_id)
        run_with_backoff do
          route53.list_resource_record_sets({
            hosted_zone_id: hosted_zone_id
          }).flat_map(&:resource_record_sets)
        end
      end

      def list_health_checks
        run_with_backoff do
          route53.list_health_checks().flat_map(&:health_checks)
        end
      end

      def get_health_check_tags(health_check_id)
        run_with_backoff do
          route53.list_tags_for_resource({
            resource_type: 'healthcheck',
            resource_id: health_check_id
          }).resource_tag_set.tags
        end
      end

      def find_health_check_by_tag(key, value)
        list_health_checks.detect do |health_check|
          get_health_check_tags(health_check.id).detect { |tag| tag.key == key && tag.value.include?(value) }
        end
      end
    end
  end
end
