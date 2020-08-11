require 'aws-sdk-eks'
require 'yaml'

module MovableInk
  class AWS
    module EKS
      def eks(region: my_region)
        @eks_client ||= {}
        @eks_client[region] ||= Aws::EKS::Client.new(region: region)
      end

      def generate_kubeconfig(region: my_region, cluster_name:)
        client = eks(region: region)

        resp = run_with_backoff do
          client.describe_cluster({ name: cluster_name })
        rescue Aws::EKS::Errors::ResourceNotFoundException
          return nil
        end

        cluster_arn = resp.cluster.arn
        cluster_server_address = resp.cluster.endpoint
        cluster_certificate_authority_data = resp.cluster.certificate_authority.data

        {
          'apiVersion' => 'v1',
          'clusters' => [{
            'cluster' => {
              'certificate-authority-data' => cluster_certificate_authority_data,
              'server' => cluster_server_address,
            },
            'name' => cluster_arn
          }],
          'contexts' => [{
            'context' => {
              'cluster' => cluster_arn,
              'user' => cluster_arn,
            },
            'name' => cluster_arn,
          }],
          'current-context' => cluster_arn,
          'kind' => 'Config',
          'preferences' => {},
          'users' => [{
            'name' => cluster_arn,
            'user' => {
              'exec' => {
                'apiVersion' => 'client.authentication.k8s.io/v1alpha1',
                'args' => ['--region', region, 'eks', 'get-token', '--cluster-name', cluster_name],
                'command' => 'aws',
              }
            }
          }]
        }.to_yaml
      end
    end
  end
end
