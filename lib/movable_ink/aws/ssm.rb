module MovableInk
  class AWS
    module SSM
      def ssm
        @ssm_client ||= Aws::SSM::Client.new(region: 'us-east-1')
      end

      def get_secret(environment: mi_env, role:, attribute:)
        run_with_backoff do
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
        run_with_backoff do
          resp = ssm.get_parameters_by_path(
                    path: path,
                    with_decryption: true
                  )
          secrets = extract_parameters(resp.parameters, path)
          while resp.next_token do
            resp = ssm.get_parameters_by_path(
                      path: path,
                      with_decryption: true,
                      next_token: resp.next_token
                    )
            secrets.merge!(extract_parameters(resp.parameters, path))
          end

          secrets
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
