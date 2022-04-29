require 'aws-sdk-ssm'

module MovableInk
  class AWS
    module SSM

      SSM_DEFAULT_REGION = 'us-east-1'
      SSM_DEFAULT_FAILOVER_REGION = 'us-west-2'

      def mi_secrets_config_file_path
        '/etc/movableink/secrets_config.json'
      end

      def mi_secrets_config
        @mi_secrets_config ||= (File.exist?(mi_secrets_config_file_path)) ? JSON.parse(File.read(mi_secrets_config_file_path), :symbolize_names => true) : nil
      end

      def mi_ssm_clients_regions
        default_regions = [SSM_DEFAULT_REGION, SSM_DEFAULT_FAILOVER_REGION]
        return default_regions if !mi_secrets_config || !mi_secrets_config[:ssm_parameters_regions_map] || mi_secrets_config[:ssm_parameters_regions_map][my_region.to_sym]
        mi_secrets_config[:ssm_parameters_regions_map][my_region.to_sym].values
      end

      def ssm_client(region = nil)
        @ssm_clients_map ||= {}
        @ssm_clients_map[region] ||= Aws::SSM::Client.new(region: (region.nil?) ? mi_ssm_clients_regions[0] : region)
      end

      def ssm_client_failover(failregion = nil)
        @ssm_failover_clients_map ||= {}
        @ssm_failover_clients_map[failregion] ||= Aws::SSM::Client.new(region: (failregion.nil?) ? mi_ssm_clients_regions[1] : failregion)
      end

      def run_with_backoff_and_client_fallback(region = nil, failregion = nil, &block)
        run_with_backoff do
          block.call(ssm_client(region))
        end
      rescue MovableInk::AWS::Errors::FailedWithBackoff => e
        run_with_backoff(tries: 3) do
          block.call(ssm_client_failover(failregion))
        end
      end

      def get_secret(environment: mi_env, role:, attribute:, region: nil, failregion: nil)
        run_with_backoff_and_client_fallback(region, failregion) do |ssm|
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

      def get_role_secrets(environment: mi_env, role:, region: nil, failregion: nil)
        path = "/#{environment}/#{role}"
        run_with_backoff_and_client_fallback(region, failregion) do |ssm|
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
