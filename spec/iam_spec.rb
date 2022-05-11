require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::IAM do
  let(:aws) { MovableInk::AWS.new }

  describe 'is_arn_iam_user?' do
    it 'matches user by arn type' do
      expect(aws.is_arn_iam_user?('arn:aws:iam::123:user/anosulchyk')).to eq true
      expect(aws.is_arn_iam_user?('arn:aws:iam::123:role/anosulchyk')).to eq false
    end

    it 'matches user by arn type and name' do
      expect(aws.is_arn_iam_user?('arn:aws:iam::123:user/anosulchyk', 'anosulchyk')).to eq true
      expect(aws.is_arn_iam_user?('arn:aws:iam::123:user/this/is/user/too', 'this/is/user/too')).to eq true
      expect(aws.is_arn_iam_user?('arn:aws:iam::123:user/anosulchyk', 'anosulchik11')).to eq false
    end
  end

   describe 'is_arn_iam_role?' do
    it 'matches role by arn type' do
      expect(aws.is_arn_iam_role?('arn:aws:iam::123:role/anosulchyk')).to eq true
      expect(aws.is_arn_iam_role?('arn:aws:sts::123:role/anosulchyk')).to eq false
    end

    it 'matches role by arn type and name' do
       expect(aws.is_arn_iam_role?('arn:aws:iam::123:role/anosulchyk', 'anosulchyk')).to eq true
      expect(aws.is_arn_iam_role?('arn:aws:iam::123:role/anosulchyk', 'anosulchik11')).to eq false
    end
  end

  describe 'is_arn_iam_assumed_role?' do
    it 'matches role by arn type' do
      expect(aws.is_arn_iam_assumed_role?('arn:aws:sts::123:assumed-role/anosulchyk/session')).to eq true
      expect(aws.is_arn_iam_assumed_role?('arn:aws:sts::123:role/anosulchyk')).to eq false
    end

    it 'matches role by arn type and name' do
       expect(aws.is_arn_iam_assumed_role?('arn:aws:sts::123:assumed-role/anosulchyk/session', 'anosulchyk')).to eq true
      expect(aws.is_arn_iam_assumed_role?('arn:aws:sts::123:assumed-role/anosulchyk/session-name', '1anosulchyk1')).to eq false
    end
  end

end
