require_relative '../lib/movable_ink/aws'
require 'webmock/rspec'

describe MovableInk::Consul do
  describe MovableInk::Consul::Kv do
    it 'get returns a hash of json content' do
      allow(Diplomat::Kv).to receive(:get).and_return({ hello: 'world' }.to_json)
      expect(MovableInk::Consul::Kv.get('ham')).to eq({ 'hello' => 'world' })
    end

    it 'returns a string if the stored value is not json' do
      value = 'some-database-password'
      allow(Diplomat::Kv).to receive(:get).and_return(value)
      expect(MovableInk::Consul::Kv.get('db_password')).to eq(value)
    end

    it 'forwards all arguments to Diplomat' do
      expect(Diplomat::Kv).to receive(:get).with('foo/', recurse: true)
      MovableInk::Consul::Kv.get('foo/', recurse: true)
    end
  end
end
