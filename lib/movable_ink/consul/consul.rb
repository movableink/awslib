require 'diplomat'

Diplomat.configure do |config|
  config.url = "https://localhost:8501"
  config.options = { ssl: { verify: false } }
end

module MovableInk
  module Consul
    module Kv
      def self.get(*args, **kwargs)
        begin
          options = kwargs
          result = Diplomat::Kv.get(*args, **options)
          JSON.parse(result) if !result.nil?
        rescue JSON::ParserError
          result
        end
      end
    end
  end
end
