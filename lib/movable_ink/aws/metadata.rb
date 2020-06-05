require 'net/http'

module MovableInk
  class AWS
    module Metadata
      def http
        @http ||= begin
          http = Net::HTTP.new("169.254.169.254", 80)
          http.open_timeout = 1
          http.read_timeout = 1
          http
        end
      end

      def retrieve_metadata(key)
        request = Net::HTTP::Get.new("/latest/meta-data/#{key}")
        request['X-aws-ec2-metadata-token'] = imds_token
        response = http.request(request)
        response.body
      rescue
        ""
      end

      def availability_zone
        @availability_zone ||= begin
          az = retrieve_metadata('placement/availability-zone')
          raise(MovableInk::AWS::Errors::EC2Required) if az.empty?
          az
        end
      end

      def instance_id
        @instance_id ||= begin
          id = retrieve_metadata('instance-id')
          raise(MovableInk::AWS::Errors::EC2Required) if id.empty?
          id
        end
      end

      def private_ipv4
        @ipv4 ||= begin
          ipv4 = retrieve_metadata('local-ipv4')
          raise(MovableInk::AWS::Errors::EC2Required) if ipv4.empty?
          ipv4
        end
      end

      private

      def imds_token
        begin
          request = Net::HTTP::Put.new('/latest/api/token')
          request['X-aws-ec2-metadata-token-ttl-seconds'] = 120
          response = http.request(request)
          response.body
        rescue
          nil
        end
      end
    end
  end
end
