require 'aws-sdk-elasticloadbalancingv2'
require 'ostruct'

module MovableInk
  class AWS
    module ELB
      def elbv2(region: my_region, client: nil)
        @elbv2_client ||= {}
        @elbv2_client[region] ||= (client) ? client : Aws::ElasticLoadBalancingV2::Client.new(region: region)
      end

      def elbv2_with_retries(region: my_region, client: nil)
        @elbv2_client_with_retries ||= {}
        if (client)
          @elbv2_client_with_retries[region] ||= client
        else
          instance_credentials = Aws::InstanceProfileCredentials.new(retries: 5, disable_imds_v1: true)
          @elbv2_client_with_retries[region] ||= Aws::ElasticLoadBalancingV2::Client.new(region: region, credentials: instance_credentials)
        end
      end

      # Get load balancer addresses with their availability zones
      #
      # @param name [String] the name of the Application Load Balancer
      # @param region [String] the AWS region (defaults to my_region)
      # @return [Array<OpenStruct>] an array of address objects with ip_address and availability_zone properties
      def alb_addresses(name:, region: my_region)
        result = run_with_backoff do
          elbv2_with_retries(region: region).describe_load_balancers(names: [name])
        end

        load_balancer = result.load_balancers.first
        raise "Load balancer '#{name}' not found" unless load_balancer

        addresses = []

        load_balancer.availability_zones.each do |az|
          az.load_balancer_addresses.each do |addr|
            ip = addr.ip_address || addr.private_ipv4_address
            next unless ip

            addresses << OpenStruct.new(
              ip_address: ip,
              availability_zone: az.zone_name,
              subnet_id: az.subnet_id
            )
          end
        end

        addresses
      end
    end
  end
end
