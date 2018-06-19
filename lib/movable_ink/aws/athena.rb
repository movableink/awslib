module MovableInk
  class AWS
    module Athena
      def athena(region: my_region)
        @athena_client ||= {}
        @athena_client[region] ||= Aws::Athena::Client.new(region: region)
      end
    end
  end
end
