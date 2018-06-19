module MovableInk
  class AWS
    module S3
      def s3
        @s3_client ||= Aws::S3::Client.new(region: 'us-east-1')
      end

      def directory_exists?(bucket:, prefix:)
        !run_with_backoff { s3.list_objects_v2(bucket: bucket, prefix: prefix, max_keys: 1).contents.empty? }
      end
    end
  end
end
