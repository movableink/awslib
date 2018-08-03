require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::ElastiCache do
  let(:aws) { MovableInk::AWS.new }
  let(:elasticache) { Aws::ElastiCache::Client.new(stub_responses: true) }

  describe "elasticache_replica_in_my_az" do
    let(:replication_group) { elasticache.stub_data(:describe_replication_groups, replication_groups: [
          replication_group_id: 'foo',
          node_groups: [{
            primary_endpoint: {address: 'primary'},
            node_group_members: [
              {preferred_availability_zone: 'us-foo-1a',
              read_endpoint: {address: 'address-1a'},
              current_role: 'replica' },
              {preferred_availability_zone: 'us-foo-1a',
                read_endpoint: {address: 'address-1a-primary'},
                current_role: 'primary' },
              {preferred_availability_zone: 'us-foo-1b',
                read_endpoint: {address: 'address-1b'},
                current_role: 'primary' },
              {preferred_availability_zone: 'us-foo-1c',
                read_endpoint: {address: 'address-1c'},
                current_role: 'replica' },
            ]
          }],
        ]
    )}

    before(:each) do
      elasticache.stub_responses(:describe_replication_groups, replication_group)
      allow(aws).to receive(:mi_env).and_return('test')
      allow(aws).to receive(:elasticache).and_return(elasticache)
    end

    it "should return the correct read address" do
      allow(aws).to receive(:availability_zone).and_return('us-foo-1a')
      expect(aws.elasticache_replica_in_my_az("foo")).to eq("address-1a")
    end

    it "should return the primary if there is no replica" do
      allow(aws).to receive(:availability_zone).and_return('us-foo-1b')
      expect(aws.elasticache_replica_in_my_az("foo")).to eq("address-1b")
    end

    it "should return an array of all replicas" do
      allow(aws).to receive(:availability_zone).and_return('us-foo-1b')
      expect(aws.all_elasticache_replicas("foo")).to eq(["address-1a", "address-1c"])
    end
  end
end
