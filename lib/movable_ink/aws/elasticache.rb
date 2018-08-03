module MovableInk
  class AWS
    module ElastiCache
      def elasticache(region: my_region)
        @elasticache_client ||= {}
        @elasticache_client[region] ||= Aws::ElastiCache::Client.new(region: region)
      end

      def replication_group(role)
        @replication_group ||= elasticache.describe_replication_groups({replication_group_id: role}).replication_groups.first
      end

      def elasticache_primary(role)
        replication_group(role).node_groups
                               .first
                               .primary_endpoint
                               .address
      end

      def elasticache_replica_in_my_az(role)
        replication_group(role).node_groups
                               .first
                               .node_group_members
                               .select{|ng| ng.preferred_availability_zone == availability_zone}
                               .first
                               .read_endpoint
                               .address
      end
    end
  end
end
