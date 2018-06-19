require_relative '../lib/movable_ink/aws'

describe MovableInk::AWS::S3 do
  let(:aws) { MovableInk::AWS.new }
  let(:s3) { Aws::S3::Client.new(stub_responses: true) }

  describe "#directory_exists?" do
    let(:existing_folder) { s3.stub_data(:list_objects_v2,
      contents: [{
        key: "foo/file",
      }],
      name: "bucket",
      prefix: "foo/",
      delimiter: "/",
      max_keys: 1,
    )}
    let(:nonexistant_folder) { s3.stub_data(:list_objects_v2,
      contents: [],
      name: "bucket",
      prefix: "bar/",
      delimiter: "/",
      max_keys: 1,
    )}

    before(:each) do
      allow(aws).to receive(:mi_env).and_return('test')
      allow(aws).to receive(:s3).and_return(s3)
    end

    it "should return true if an S3 directory exists" do
      s3.stub_responses(:list_objects_v2, existing_folder)

      expect(aws.directory_exists?(bucket: "bucket", prefix: "foo/")).to eq(true)
    end

    it "should return false if an S3 directory doesn't exist" do
      s3.stub_responses(:list_objects_v2, nonexistant_folder)

      expect(aws.directory_exists?(bucket: "bucket", prefix: "bar/")).to eq(false)
    end
  end
end
