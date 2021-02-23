require 'time'
require 'json'
require 'aws-sdk-sns'

module MovableInk
  class AWS
    module SNS
      def sns(region: my_region)
        @sns_client ||= {}
        @sns_client[region] ||= Aws::SNS::Client.new(region: region)
      end

      def sns_slack_topic_arn
        @sns_slack_topic_arn ||= sns_topics.detect { |topic| topic.topic_arn.include? "slack-aws-alerts" }.topic_arn rescue nil
      end

      def sns_pagerduty_topic_arn
        @sns_pagerduty_topic_arn ||= sns_topics.detect { |topic| topic.topic_arn.include? "pagerduty-custom-alerts" }.topic_arn rescue nil
      end

      def sns_topics
        @sns_topics ||= run_with_backoff { sns.list_topics.flat_map(&:topics) }
      end

      def notify_and_sleep(seconds, error_class)
        message = "Throttled by AWS. Sleeping #{seconds} seconds, (#{error_class})"
        notify_slack(subject: 'API Throttled', message: message)
        puts message
        sleep seconds
      end

      def send_alert(
        source: instance_id,
        links: [],
        custom_details: {},
        summary:,
        dedup_key:
      )
        run_with_backoff do
          message_json = pd_message_json({
            source: source,
            summary: summary,
            links: links,
            custom_details: custom_details,
            dedup_key: dedup_key,
          })

          sns.publish({
            topic_arn: sns_pagerduty_topic_arn,
            subject: summary,
            message: message_json
          })
        end
      end

      def notify_slack(subject:, message:)
        instance_link = "<https://#{my_region}.console.aws.amazon.com/ec2/v2/home?region=#{my_region}#Instances:search=#{instance_id};sort=instanceId|#{instance_id}>"
        required_info = "Instance: #{instance_link}, `#{private_ipv4}`, `#{my_region}`"

        run_with_backoff do
          sns.publish(topic_arn: sns_slack_topic_arn,
                      subject: subject.slice(0,99),
                      message: "#{required_info}\n#{message}")
        end
      end

      private

      def pd_message_json(
        source:,
        summary:,
        links:,
        custom_details:,
        dedup_key:
      )
        {
          pagerduty: {
            event_action: 'trigger',
            payload: {
              source: source,
              summary: summary,
              timestamp: Time.now.utc.iso8601,
              severity: 'error',
              component: source,
              group: source,
              custom_details: custom_details,
            },
            dedup_key: dedup_key,
            links: links,
          }
        }.to_json
      end
    end
  end
end
