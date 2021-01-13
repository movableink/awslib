require 'diplomat'

Diplomat.configure do |config|
  config.url = "https://localhost:8501"
  config.options = { ssl: { verify: false } }
end

module MovableInk
  module Consul
    module Kv
      def self.get(*args)
        begin
          result = Diplomat::Kv.get(*args)
          JSON.parse(result) if !result.nil?
        rescue JSON::ParserError
          result
        end
      end
    end
  end
end
