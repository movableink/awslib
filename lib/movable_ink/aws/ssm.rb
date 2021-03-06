require 'aws-sdk-ssm'

module MovableInk
  class AWS
    module SSM
      def ssm_client
        @ssm_client ||= Aws::SSM::Client.new(region: 'us-east-1')
      end

      def ssm_client_failover
        @ssm_client_failover ||= Aws::SSM::Client.new(region: 'us-west-2')
      end

      def run_with_backoff_and_client_fallback(&block)
        run_with_backoff do
          block.call(ssm_client)
        end
      rescue MovableInk::AWS::Errors::FailedWithBackoff => e
        run_with_backoff(tries: 3) do
          block.call(ssm_client_failover)
        end
      end

      def get_secret(environment: mi_env, role:, attribute:)
        run_with_backoff_and_client_fallback do |ssm|
          begin
            resp = ssm.get_parameter(
                      name: "/#{environment}/#{role}/#{attribute}",
                      with_decryption: true
                    )
            resp.parameter.value
          rescue Aws::SSM::Errors::ParameterNotFound => e
            nil
          end
        end
      end

      def get_role_secrets(environment: mi_env, role:)
        path = "/#{environment}/#{role}"
        run_with_backoff_and_client_fallback do |ssm|
          ssm.get_parameters_by_path(
            path: path,
            with_decryption: true
          ).inject({}) do |secrets, resp|
            secrets.merge!(extract_parameters(resp.parameters, path))
          end
        end
      end

      def extract_parameters(parameters, path)
        parameters.map do |param|
          [ param.name.gsub("#{path}/", ''), param.value ]
        end.to_h
      end
    end
  end
end
