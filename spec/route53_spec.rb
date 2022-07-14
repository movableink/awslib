require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::Route53 do
  let(:aws) { MovableInk::AWS.new }

  context "resource record sets" do
    let(:route53) { Aws::Route53::Client.new(stub_responses: true) }
    let(:rrset_data) { route53.stub_data(:list_resource_record_sets, resource_record_sets: [
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
