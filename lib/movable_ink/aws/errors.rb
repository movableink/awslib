module MovableInk
  class AWS
    module Errors
      class ServiceError < StandardError; end
      class FailedWithBackoff < StandardError; end
      class EC2Required < StandardError; end
      class NoEnvironmentTagError < StandardError; end
      class InvalidDiscoveryTypeError < StandardError; end
      class RoleNameRequiredError < StandardError; end
      class RoleNameInvalidError < StandardError; end
    end
  end
end
