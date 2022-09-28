module MovableInk
  class AWS
    module Errors
      class ServiceError < StandardError; end
      class FailedWithBackoff < StandardError; end
      class MetadataTimeout < StandardError; end
      class NoEnvironmentTagError < StandardError; end
      class InvalidDiscoveryTypeError < StandardError; end
      class RoleNameRequiredError < StandardError; end
      class RoleNameInvalidError < StandardError; end
      class AvailabilityZonesListInvalidError < StandardError; end

      class ExpectedError
        def initialize(error_class, message_patterns = [])
          @error_class = error_class
          message_patterns.each { |pattern| raise StandardError.new("Invalid message pattern provided #{pattern.inspect}") unless pattern.class == Regexp }
          @message_patterns = message_patterns
        end

        def match?(exception)
          return false unless exception.class == @error_class
          return true if @message_patterns.length == 0
          @message_patterns.each {|pattern| return true if exception.message.match(pattern) }
          false
        end
      end
    end
  end
end
