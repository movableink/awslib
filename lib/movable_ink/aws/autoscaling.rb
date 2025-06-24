require 'aws-sdk-autoscaling'

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

      def delete_role_tag_with_retries(role:)
        run_with_backoff do
          ec2_with_retries.delete_tags({
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

      def complete_lifecycle_action(lifecycle_hook_name:, auto_scaling_group_name:, lifecycle_action_token: nil, instance_id: nil)
        raise ArgumentError.new('lifecycle_action_token or instance_id required') if lifecycle_action_token.nil? && instance_id.nil?

        if lifecycle_action_token
          run_with_backoff do
            autoscaling.complete_lifecycle_action({
              lifecycle_hook_name:     lifecycle_hook_name,
              auto_scaling_group_name: auto_scaling_group_name,
              lifecycle_action_token:  lifecycle_action_token,
              lifecycle_action_result: 'CONTINUE'
            })
          end
        else
          run_with_backoff do
            autoscaling.complete_lifecycle_action({
              instance_id:             instance_id,
              lifecycle_hook_name:     lifecycle_hook_name,
              auto_scaling_group_name: auto_scaling_group_name,
              lifecycle_action_result: 'CONTINUE'
            })
          end
        end
      end

      def record_lifecycle_action_heartbeat(lifecycle_hook_name:, auto_scaling_group_name:, lifecycle_action_token: nil, instance_id: nil)
        raise ArgumentError.new('lifecycle_action_token or instance_id required') if lifecycle_action_token.nil? && instance_id.nil?

        if lifecycle_action_token
          run_with_backoff do
            autoscaling.record_lifecycle_action_heartbeat({
              lifecycle_hook_name:     lifecycle_hook_name,
              auto_scaling_group_name: auto_scaling_group_name,
              lifecycle_action_token:  lifecycle_action_token
            })
          end
        else
          run_with_backoff do
            autoscaling.record_lifecycle_action_heartbeat({
              instance_id:             instance_id,
              lifecycle_hook_name:     lifecycle_hook_name,
              auto_scaling_group_name: auto_scaling_group_name,
            })
          end
        end
      end

      def keep_instance_alive(lifecycle_hook_name:, auto_scaling_group_name:, lifecycle_action_token: nil, instance_id: nil)
        24.downto(1) do |hours|
          record_lifecycle_action_heartbeat(
            lifecycle_hook_name: lifecycle_hook_name,
            auto_scaling_group_name: auto_scaling_group_name,
            lifecycle_action_token: lifecycle_action_token,
            instance_id: instance_id
          )
          sleep 3600
        end
      end

    end
  end
end
