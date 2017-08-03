module MovableInk
  class AWS
    module Autoscaling
      def autoscaling(region: my_region)
        @autoscaling_client ||= {}
        @autoscaling_client[region] ||= Aws::AutoScaling::Client.new(region: region)
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
    end
  end
end
