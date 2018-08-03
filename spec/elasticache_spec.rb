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
              read_endpoint: {address: 'address-1a'} },
              {preferred_availability_zone: 'us-foo-1b',
                read_endpoint: {address: 'address-1b'} }
            ]
          }],
        ]
    )}

    before(:each) do
      elasticache.stub_responses(:describe_replication_groups, replication_group)
      allow(aws).to receive(:mi_env).and_return('test')
      allow(aws).to receive(:availability_zone).and_return('us-foo-1a')
      allow(aws).to receive(:elasticache).and_return(elasticache)
    end

    it "should return the correct read address" do
      expect(aws.elasticache_replica_in_my_az("foo")).to eq("address-1a")
    end
  end
end
