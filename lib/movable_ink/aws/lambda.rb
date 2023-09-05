require 'aws-sdk-lambda'

module MovableInk
  class AWS
    module Lambda
      def lambda(region: my_region)
        @lambda_client ||= {}
        @lambda_client[region] ||= Aws::Lambda::Client.new(region: region)
      end

      def disable_autoscaling_lambda
        function_name = 'autoscaling-scheduled-capacity-production-cleanup'

        lambda.update_function_configuration({
          function_name: function_name,
          environment: {
            variables: {
              "DRY_RUN" => "true",
            }
          }
        })
      end

      def enable_autoscaling_lambda
        function_name = 'autoscaling-scheduled-capacity-production-cleanup'

        lambda.update_function_configuration({
          function_name: function_name,
          environment: {
            variables: {
              "DRY_RUN" => "false",
            }
          }
        })
      end

    end
  end
end
