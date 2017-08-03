module MovableInk
  class AWS
    module Errors
      class FailedWithBackoff < StandardError; end
      class EC2Required < StandardError; end
    end
  end
end
