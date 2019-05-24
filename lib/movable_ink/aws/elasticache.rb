module MovableInk
  class AWS
    module ElastiCache
      def elasticache(region: my_region)
        @elasticache_client ||= {}
        @elasticache_client[region] ||= Aws::ElastiCache::Client.new(region: region)
      end

      def replication_group(name)
        run_with_backoff do
          @replication_group ||= elasticache
            .describe_replication_groups(replication_group_id: name)
            .replication_groups
            .first
        end
      end

      def elasticache_primary(name)
        replication_group(name)
          .node_groups
          .first
          .primary_endpoint
          .address
      end

      def node_group_members(name)
        replication_group(name)
          .node_groups
          .first
          .node_group_members
      end

      def node_group_members_in_my_az(name)
        node_group_members(name)
          .select { |ng| ng.preferred_availability_zone == availability_zone }
      end

      def elasticache_replicas(name)
        node_group_members(name)
          .select { |ng| ng.current_role == 'replica' }
      end

      def all_elasticache_replicas(name)
        elasticache_replicas(name)
          .map { |replica| replica.read_endpoint.address }
      end

      def elasticache_replica_in_my_az(name)
        members = node_group_members_in_my_az(name)
        begin
          members
            .select{|ng| ng.current_role == 'replica'}
            .first
            .read_endpoint
            .address
        rescue NoMethodError
          members
            .first
            .read_endpoint
            .address
        end
      end
    end
  end
end
