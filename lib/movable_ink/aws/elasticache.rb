module MovableInk
  class AWS
    module ElastiCache
      def elasticache(region: my_region)
        @elasticache_client ||= {}
        @elasticache_client[region] ||= Aws::ElastiCache::Client.new(region: region)
      end

      def replication_group(role)
        run_with_backoff do
          @replication_group ||= elasticache.describe_replication_groups({replication_group_id: "#{mi_env}-#{role}"}).replication_groups.first
        end
      end

      def elasticache_primary(role)
        replication_group(role).node_groups
                               .first
                               .primary_endpoint
                               .address
      end

      def all_elasticache_replicas(role)
        replication_group(role).node_groups
                               .first
                               .node_group_members
                               .select{|ng| ng.current_role == 'replica'}
                               .map{|member| member.read_endpoint.address}
      end

      def elasticache_replica_in_my_az(role)
        members = replication_group(role).node_groups
                                         .first
                                         .node_group_members
                                         .select{|ng| ng.preferred_availability_zone == availability_zone}
        begin
          members.select{|ng| ng.current_role == 'replica'}
          .first
          .read_endpoint
          .address
        rescue NoMethodError
          members.first
                 .read_endpoint
                 .address
        end
      end
    end
  end
end
