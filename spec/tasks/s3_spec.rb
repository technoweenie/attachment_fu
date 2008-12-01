require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module AttachmentFu
  class S3TaskAsset < ActiveRecord::Base
    is_faux_attachment do
      task :s3, :bucket_name => "attachment_fu_s3_test"
    end
  end

  describe "S3 Task" do
    before :all do
      if s3_loaded?
        S3TaskAsset.setup_spec_env
        @samples  = File.join(File.dirname(__FILE__), 'pixels', 'samples')
        @original = File.join(@samples, 'casshern.jpg')
        @sample   = File.join(@samples, 'sample.jpg')
        FileUtils.cp @original, @sample
        @asset = S3TaskAsset.new :content_type => 'image/jpg'
        @asset.set_temp_path @sample
        @asset.save!
      end
    end

    it "generates #s3_path" do
      "/#{@asset.s3_path}".should == @asset.public_path
    end

    it "generates #s3_url" do
      @asset.s3_url.should == "#{@asset.s3_task.protocol}#{@asset.s3_task.hostname}#{@asset.s3_task.port_string}/#{@asset.s3_task.bucket_name}#{@asset.public_path}"
    end

    it "generates #s3_url for thumbnail" do
      @asset.s3_url(:foo).should == "#{@asset.s3_task.protocol}#{@asset.s3_task.hostname}#{@asset.s3_task.port_string}/#{@asset.s3_task.bucket_name}#{@asset.public_path(:foo)}"
    end

    it "#s3_object retrieves meta data" do
      @asset.s3_object.content_type.should == @asset.content_type
      @asset.s3_object.size.should         == @asset.size
    end

    it "#s3_stream streams object data" do
      begin
        t = Tempfile.new("s3streamtest")
        @asset.s3_stream do |chunk|
          t.write chunk
        end
        t.close
        t.size.should == @asset.size
      rescue EOFError
        pending "AWS::S3 streaming seems to be busted: #{$!.to_s}"
      end
    end

    before do
      pending "setup spec/s3.yml to run this spec" unless s3_loaded?
    end

    def s3_loaded?
      AttachmentFu::Tasks::S3.connected?
    end
    
    after :all do
      S3TaskAsset.drop_spec_env if s3_loaded?
      FileUtils.rm_rf AttachmentFu.root_path
    end
  end
end