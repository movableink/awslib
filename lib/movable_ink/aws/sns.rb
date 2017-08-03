module MovableInk
  class AWS
    module SNS
      def sns(region: my_region)
        @sns_client ||= {}
        @sns_client[region] ||= Aws::SNS::Client.new(region: region)
      end

      def sns_slack_topic_arn
        run_with_backoff do
          sns.list_topics.topics.select {|topic| topic.topic_arn.include? "slack-aws-alerts"}
             .first.topic_arn
        end
      end

      def notify_and_sleep(seconds, error_class)
        message = "Throttled by AWS. Sleeping #{seconds} seconds, (#{error_class})"
        notify_slack(subject: 'API Throttled',
                     message: message)
        puts message
        sleep seconds
      end

      def notify_nsq_can_not_be_drained
        notify_slack(subject: 'NSQ not drained',
                     message: 'Unable to drain NSQ')
      end

      def notify_slack(subject:, message:)
        run_with_backoff do
          sns.publish(topic_arn: sns_slack_topic_arn,
                      subject: "#{subject} (#{instance_id}, #{my_region})",
                      message: message)
        end
      end
    end
  end
end