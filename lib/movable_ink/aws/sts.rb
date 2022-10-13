require 'aws-sdk-sts'

module MovableInk
  class AWS
    module STS
      def sts(region: my_region, client: nil)
        @sts_client ||= {}
        @sts_client[region] ||= (client) ? client : Aws::STS::Client.new(region: region)
      end

      def get_caller_identity(region: my_region, client: nil)
        sts(region: region, client: client).get_caller_identity
      end
    end
  end
end
