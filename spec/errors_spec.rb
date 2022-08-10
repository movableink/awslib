require_relative '../lib/movable_ink/aws'
require 'webmock/rspec'

describe MovableInk::AWS::Errors do
  context 'ExpectedError' do
    it 'matches exception by class name and pattern' do
      expected = MovableInk::AWS::Errors::ExpectedError.new(Aws::Errors::ServiceError, [/something failed/])
      expect(expected.match?(Aws::Errors::ServiceError.new(nil, 'There\'s something failed.'))).to eq(true)
    end

    it 'matches exception by class name only' do
      expected = MovableInk::AWS::Errors::ExpectedError.new(Aws::Errors::ServiceError)
      expect(expected.match?(Aws::Errors::ServiceError.new(nil, 'There\'s something failed.'))).to eq(true)
    end

    it 'matches exception by class name only - negative match' do
      expected = MovableInk::AWS::Errors::ExpectedError.new(Aws::IAM::Errors::Throttling)
      expect(expected.match?(Aws::Errors::ServiceError.new(nil, 'There\'s something failed.'))).to eq(false)
    end
  end
end
