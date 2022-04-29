require 'aws-sdk-iam'

module MovableInk
  class AWS
    module IAM
      def self.is_arn_iam_user?(arn, username = nil)
        # arn:aws:iam::account:user/user-name-with-path
        !arn.match(/arn:aws:iam::\d+:user\/#{(username) ? username + '$' : ''}/).nil?
      end

      def self.is_arn_iam_role?(arn, rolename = nil)
        # arn:aws:iam::account:role/role-name-with-path
        !arn.match(/arn:aws:iam::\d+:role\/#{(rolename) ? rolename + '$' : ''}/).nil?
      end

      def self.is_arn_iam_assumed_role?(arn, rolename = nil, exact_match = true)
        # arn:aws:sts::account:assumed-role/role-name/role-session-name
        role_name_session_delimiter = (exact_match) ? '/' : ''
        !arn.match(/arn:aws:sts::\d+:assumed\-role\/#{(rolename) ? rolename + role_name_session_delimiter : ''}/).nil?
      end
    end
  end
end
