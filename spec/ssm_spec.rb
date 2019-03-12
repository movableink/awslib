require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::SSM do
  let(:aws) { MovableInk::AWS.new }
  let(:ssm) { Aws::SSM::Client.new(stub_responses: true) }
  let(:parameter) { ssm.stub_data(:get_parameter, parameter: {
      name: '/test/sneakers/setec-astronomy',
      type: 'SecureString',
      value: 'too-many-secrets'
    })
  }
  let(:parameters) { ssm.stub_data(:get_parameters_by_path, parameters: [
      {
        name: '/test/zelda/Its',
        type: 'SecureString',
        value: "It's"
      },
      {
        name: '/test/zelda/a',
        type: 'SecureString',
        value: "dangerous"
      },
      {
        name: '/test/zelda/secret',
        type: 'SecureString',
        value: "to"
      },
      {
        name: '/test/zelda/to',
        type: 'SecureString',
        value: "go"
      },
      {
        name: '/test/zelda/everyone',
        type: 'SecureString',
        value: "alone"
      }
    ])
  }
  let(:zelda_secrets) {
    {
      "Its"      => "It's",
      "a"        => "dangerous",
      "secret"   => "to",
      "to"       => "go",
      "everyone" => "alone"
    }
  }

  it "should retrieve a decrypted secret" do
    ssm.stub_responses(:get_parameter, parameter)
    allow(aws).to receive(:mi_env).and_return('test')
    allow(aws).to receive(:us_east_ssm).and_return(ssm)

    expect(aws.get_secret(role: 'sneakers', attribute: 'setec-astronomy')).to eq('too-many-secrets')
  end

  it "should retrieve all secrets for a role" do
    ssm.stub_responses(:get_parameters_by_path, parameters)
    allow(aws).to receive(:mi_env).and_return('test')
    allow(aws).to receive(:us_east_ssm).and_return(ssm)

    expect(aws.get_role_secrets(role: 'zelda')).to eq(zelda_secrets)
  end

  describe 'run_with_backoff_and_client_fallback' do
    it 'passes in the us_east_ssm client and then the us_west_ssm client' do
      allow(aws).to receive(:us_east_ssm).and_return(1)
      allow(aws).to receive(:us_west_ssm).and_return(2)
      allow(aws).to receive(:notify_and_sleep).and_return(nil)

      results = []
      calls = 0

      begin
        aws.run_with_backoff_and_client_fallback do |client|
          calls += 1
          results.push(client)
          raise Aws::EC2::Errors::RequestLimitExceeded.new('context', 'message')
        end
      rescue
      end

      # 9 calls for the first client and 3 calls for the second client
      expect(calls).to eq(12)
      # the results will include the mock values for each of the clients
      expect(results).to include(1, 2)
    end
  end
end
