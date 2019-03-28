require 'time'
require 'json'

module MovableInk
  class AWS
    module SNS
      def sns(region: my_region)
        @sns_client ||= {}
        @sns_client[region] ||= Aws::SNS::Client.new(region: region)
      end

      def sns_slack_topic_arn
        run_with_backoff do
          sns.list_topics.each do |resp|
            resp.topics.each do |topic|
              return topic.topic_arn if topic.topic_arn.include? "slack-aws-alerts"
            end
          end
        end
      end

      def sns_pagerduty_topic_arn
        run_with_backoff do
          sns.list_topics.each do |resp|
            resp.topics.each do |topic|
              return topic.topic_arn if topic.topic_arn.include? "pagerduty-custom-alerts"
            end
          end
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
                     message: "Unable to drain NSQ for instance <https://#{my_region}.console.aws.amazon.com/ec2/v2/home?region=#{my_region}#Instances:search=#{instance_id};sort=instanceId|#{instance_id}>")
        notify_pagerduty(region: my_region, instance_id: instance_id)
      end

      def notify_pagerduty(region:, instance_id:)
        subject = "Unable to drain NSQ"
        summary = "Unable to drain NSQ for instance #{instance_id} in region #{region}"

        # the PagerDuty integration key is added to the payload in the AWS integration
        json_message = {
          pagerdutyPayload: {
            event_action: 'trigger',
            payload: {
              source: 'MovableInkAWS',
              summary: summary,
              timestamp: Time.now.utc.iso8601,
              severity: 'error',
              component: 'nsq',
              group: 'nsq',
              custom_details: {
                InstanceId: instance_id,
              },
            },
            dedup_key: "nsq-not-draining-#{instance_id}",
            links: [{
              href: "https://#{region}.console.aws.amazon.com/ec2/v2/home?region=#{region}#Instances:search=#{instance_id};sort=instanceId",
              text: 'View Instance'
            }],
          }
        }.to_json

        run_with_backoff do
          subject = add_subject_info(subject: subject)
          sns.publish(topic_arn: sns_pagerduty_topic_arn,
                      subject: subject,
                      message: json_message)
        end
      end

      def add_subject_info(subject:)
        required_info = " (#{instance_id}, #{my_region})"
        "#{subject.slice(0, 99-required_info.length)}#{required_info}"
      end

      def notify_slack(subject:, message:)
        run_with_backoff do
          subject = add_subject_info(subject: subject)
          sns.publish(topic_arn: sns_slack_topic_arn,
                      subject: subject,
                      message: message)
        end
      end
    end
  end
end
