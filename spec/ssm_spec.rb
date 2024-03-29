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
  let(:mi_secrets_config_file_path) { '/etc/movableink/secrets_config.json' }
  let(:mi_secrets_config_file_mock) { "{\"ssm_parameters_regions_map\": { \"us-east-1\": {\"primary_region\": \"us-east-1\", \"failover_region\": \"us-east-2\"}}}" }
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
    allow(aws).to receive(:ssm_client).and_return(ssm)

    expect(aws.get_secret(role: 'sneakers', attribute: 'setec-astronomy')).to eq('too-many-secrets')
  end

  it "should retrieve all secrets for a role" do
    ssm.stub_responses(:get_parameters_by_path, parameters)
    allow(aws).to receive(:mi_env).and_return('test')
    allow(aws).to receive(:ssm_client).and_return(ssm)

    expect(aws.get_role_secrets(role: 'zelda')).to eq(zelda_secrets)
  end

  describe 'ssm_client' do
    it 'uses to us-east-1 as a primary for secrets' do
      expect(Aws::SSM::Client).to receive(:new).with({ region: 'us-east-1' })
      aws.ssm_client
    end

    it 'Allows region to be defined as a parameter' do
      expect(Aws::SSM::Client).to receive(:new).with({ region: 'us-east-2' })
      aws.ssm_client('us-east-2')
    end
  end

  describe 'ssm_client_failover' do
    it 'fails over to us-west-2' do
      expect(Aws::SSM::Client).to receive(:new).with({ region: 'us-west-2' })
      aws.ssm_client_failover
    end

    it 'fails over to parameter defined region' do
      expect(Aws::SSM::Client).to receive(:new).with({ region: 'us-west-1' })
      aws.ssm_client_failover('us-west-1')
    end
  end

  describe 'run_with_backoff_and_client_fallback' do
    it 'passes in the ssm_client client and then the ssm_client_failover client' do
      allow(aws).to receive(:ssm_client).and_return(1)
      allow(aws).to receive(:ssm_client_failover).and_return(2)
      allow(aws).to receive(:notify_and_sleep).and_return(nil)
      allow(aws).to receive(:notify_slack).and_return(nil)
      allow(STDOUT).to receive(:puts).and_return(nil)

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

  describe 'mi_secrets_config_file_path' do
    it 'returns string' do
      expect(aws.mi_secrets_config_file_path).to eq mi_secrets_config_file_path
    end
  end

  describe 'mi_secrets_config' do
    it 'parses config file with symbols' do
       allow(File).to receive(:read).with(mi_secrets_config_file_path).and_return(mi_secrets_config_file_mock)
       allow(File).to receive(:exist?).with(mi_secrets_config_file_path).and_return(true)

       config = aws.mi_secrets_config
       expect(config.keys).to eq([:ssm_parameters_regions_map])
       expect(config[:ssm_parameters_regions_map][:"us-east-1"][:primary_region]).to eq 'us-east-1'
       expect(config[:ssm_parameters_regions_map][:"us-east-1"][:failover_region]).to eq 'us-east-2'
    end
  end

  describe 'mi_ssm_clients_regions' do
    it 'returns values from config' do
      allow(aws).to receive(:mi_secrets_config).and_return(JSON.parse(mi_secrets_config_file_mock, :symbolize_names => true))
      allow(aws).to receive(:my_region).and_return('us-east-1')
      expect(aws.mi_ssm_clients_regions).to eq ['us-east-1', 'us-east-2']
    end

    it 'returns default values if config is missing' do
      allow(aws).to receive(:mi_secrets_config).and_return(nil)
      allow(aws).to receive(:my_region).and_return('us-east-1')
      expect(aws.mi_ssm_clients_regions).to eq ['us-east-1', 'us-west-2']
    end
  end
end
