require 'net/http'
require 'json'

module MovableInk
  class AWS
    module Metadata
      def http(timeout_seconds: 1)
        @http = begin
          http = Net::HTTP.new("169.254.169.254", 80)
          http.open_timeout = timeout_seconds
          http.read_timeout = timeout_seconds
          http
        end
      end

      def retrieve_data(url, tries: 3)
        tries.times do |num|
          num += 1
          request = Net::HTTP::Get.new(url)
          request['X-aws-ec2-metadata-token'] = imds_token
          response = http(timeout_seconds: num * 3).request(request)
          return response.body
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::EHOSTDOWN
          sleep(num * 2)
        end

        raise MovableInk::AWS::Errors::MetadataTimeout
      end

      def retrieve_metadata(key, tries: 3)
        retrieve_data("/latest/meta-data/#{key}", tries: tries)
      end

      def retrieve_dynamicdata(key, tries: 3)
        retrieve_data("/latest/dynamic/#{key}", tries: tries)
      end

      def instance_identity_document
        @instance_identity_document ||= JSON.parse(retrieve_dynamicdata('instance-identity/document'))
      rescue JSON::ParserError
        return
      end

      def availability_zone
        @availability_zone ||= retrieve_metadata('placement/availability-zone')
      end

      def instance_id
        @instance_id ||= retrieve_metadata('instance-id')
      end

      def instance_type
        @instance_type ||= retrieve_metadata('instance-type')
      end

      def private_ipv4
        @ipv4 ||= retrieve_metadata('local-ipv4')
      end

      private

      def imds_token(tries: 3)
        tries.times do |num|
          num += 1
          request = Net::HTTP::Put.new('/latest/api/token')
          request['X-aws-ec2-metadata-token-ttl-seconds'] = 120
          response = http(timeout_seconds: num * 3).request(request)
          return response.body
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::EHOSTDOWN
          sleep(num * 2)
        end

        raise MovableInk::AWS::Errors::MetadataTimeout
      end
    end
  end
end
