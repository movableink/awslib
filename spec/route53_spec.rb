require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::Route53 do
  let(:aws) { MovableInk::AWS.new }

  context 'hosted zones' do
    let(:route53) { Aws::Route53::Client.new(stub_responses: true) }

    it "should list all hosted zones" do
      zones_data = route53.stub_data(:list_hosted_zones, is_truncated: false, hosted_zones: [{
        id: '123456789X',
        name: 'domain.tld',
        caller_reference: '123'
      }])
      route53.stub_responses(:list_hosted_zones, zones_data)
      allow(aws).to receive(:route53).and_return(route53)

      expect(aws.list_hosted_zones.count).to eq(1)
      expect(aws.list_hosted_zones.first.id).to eq('123456789X')
      expect(aws.list_hosted_zones.first.name).to eq('domain.tld')
    end

    it "should list all hosted zones w/ pagination" do
      zones_response_1 = {
        is_truncated: true,
        next_marker: 'this is fake marker',
        marker: 'this is fake marker',
        max_items: 1,
        hosted_zones: [{
          id: '123456789X',
          name: 'domain.tld',
          caller_reference: '123'
      }]}

      zones_response_2 = {
        is_truncated: false,
        next_marker: nil,
        marker: 'this is fake marker',
        max_items: 1,
        hosted_zones: [{
          id: 'X123456789',
          name: 'tld.domain',
          caller_reference: '321'
      }]}

      route53.stub_responses(:list_hosted_zones, [ zones_response_1, zones_response_2 ])
      allow(aws).to receive(:route53).and_return(route53)

      zones = aws.list_hosted_zones
      expect(zones.count).to eq(2)
      expect(zones.first.id).to eq('123456789X')
      expect(zones.first.name).to eq('domain.tld')
      expect(zones[1].id).to eq('X123456789')
      expect(zones[1].name).to eq('tld.domain')
    end
  end

  context "resource record sets" do
    let(:route53) { Aws::Route53::Client.new(stub_responses: true) }
    let(:rrset_data) { route53.stub_data(:list_resource_record_sets, is_truncated: false, resource_record_sets: [
        {
          name: 'host1.domain.tld.',
          set_identifier: '10_0_0_1',
          type: '???'
        },
        {
          name: 'host2.domain.tld.',
          set_identifier: '10_0_0_2',
          type: '???'
        },
        {
          name: 'host2-other.domain.tld.',
          set_identifier: '10_0_0_2',
          type: '???'
        }
      ])
    }

    it "should retrieve all rrsets for zone" do
      route53.stub_responses(:list_resource_record_sets, rrset_data)
      allow(aws).to receive(:route53).and_return(route53)

      expect(aws.resource_record_sets('Z123').count).to eq(3)
      expect(aws.resource_record_sets('Z123')[0].name).to eq('host1.domain.tld.')
      expect(aws.resource_record_sets('Z123')[1].name).to eq('host2.domain.tld.')
      expect(aws.resource_record_sets('Z123')[2].name).to eq('host2-other.domain.tld.')
    end

    it "should retrieve all rrsets for zone w/ pagination" do

      rrs_response_1 = {
        is_truncated: true,
        max_items: 1,
        next_record_name: 'record2.domain.',
        next_record_type: 'A',
        next_record_identifier: nil,
        resource_record_sets: [{
          name: 'record1.domain.',
          type: 'A',
          set_identifier: nil
      }]}

      rrs_response_2 = {
        is_truncated: false,
        max_items: 1,
        next_record_name: nil,
        next_record_type: nil,
        next_record_identifier: nil,
        resource_record_sets: [{
          name: 'record2.domain.',
          type: 'A',
          set_identifier: nil
      }]}

      rrset_data = [rrs_response_1, rrs_response_2]
      route53.stub_responses(:list_resource_record_sets, rrset_data)
      allow(aws).to receive(:route53).and_return(route53)

      rrs = aws.resource_record_sets('Z123')
      expect(rrs.count).to eq(2)
      expect(rrs[0].name).to eq('record1.domain.')
      expect(rrs[1].name).to eq('record2.domain.')
    end

    it "returns all sets with an identifier" do
      route53.stub_responses(:list_resource_record_sets, rrset_data)
      allow(aws).to receive(:route53).and_return(route53)

      sets = aws.get_resource_record_sets_by_instance_name('Z123', '10_0_0_2')
      expect(sets.count).to eq(2)
      expect(sets[0][:name]).to eq('host2.domain.tld.')
      expect(sets[1][:name]).to eq('host2-other.domain.tld.')
    end

    it 'deletes rrsets that exist under the same identifier' do
      route53.stub_responses(:list_resource_record_sets, rrset_data)
      allow(aws).to receive(:route53).and_return(route53)

      expect(route53).to receive(:change_resource_record_sets).with({
        change_batch: {
          changes: [{
            action: "DELETE",
            resource_record_set: {
              name: "host2.domain.tld.",
              type: "???",
              set_identifier: "10_0_0_2"
            }
          },
          {
            action: "DELETE",
            resource_record_set: {
              name: "host2-other.domain.tld.",
              type: "???",
              set_identifier: "10_0_0_2"
            }
          }]
        },
        hosted_zone_id: "Z123"
      })
      aws.delete_resource_record_sets('Z123', '10_0_0_2')
    end

    it 'doesnt error deleting the rrset if the rrset doesnt exist' do
      route53.stub_responses(:list_resource_record_sets, rrset_data)
      allow(aws).to receive(:route53).and_return(route53)
      expect(route53).to_not receive(:change_resource_record_sets)
      expect { aws.delete_resource_record_sets('Z123', '10_0_0_3') }.to_not raise_error
    end
  end
end
