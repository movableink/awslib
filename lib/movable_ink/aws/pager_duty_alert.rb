require 'json'
require 'time'
require 'aws-sdk-sns'

class PagerDutyAlert
  def initialize(
    client:,
    source:,
    summary:,
    dedup_key:,
    topic_arn:,
    links: [],
    custom_details: {}
  )
    @client = client
    @source = source
    @summary = summary
    @links = links
    @dedup_key = dedup_key
    @custom_details = custom_details
    @topic_arn = topic_arn
  end

  def message_hash
    {
      pagerduty: {
        event_action: 'trigger',
        payload: {
          source: @source,
          summary: @summary,
          timestamp: Time.now.utc.iso8601,
          severity: 'error',
          component: @source,
          group: @source,
          custom_details: @custom_details,
        },
        dedup_key: @dedup_key,
        links: @links,
      }
    }
  end

  def publish
    @client.publish({
      topic_arn: @topic_arn,
      subject: @summary,
      message: message_hash.to_json
    })
  end
end
