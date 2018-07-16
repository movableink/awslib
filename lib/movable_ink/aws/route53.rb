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
        change_batch = {
          "changes": [{
            "action": 'DELETE',
            "resource_record_set": get_resource_record_sets_by_instance_name(zone, instance_name)
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
    end
  end
end
