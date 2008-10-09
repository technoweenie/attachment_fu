require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module AttachmentFu
  class S3TaskAsset < ActiveRecord::Base
    is_faux_attachment do
      task :s3, :config => File.expand_path(File.join(File.dirname(__FILE__), '..', 's3.yml')), :ignore_missing_config => true
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
      end
    end

    describe "with default options" do
      before :all do
        @asset.save! if s3_loaded?
      end

      it "generates #s3_path" do
        @asset.s3_url.should == "#{@asset.s3_task.protocol}#{@asset.s3_task.hostname}#{@asset.s3_task.port_string}/#{@asset.s3_task.bucket_name}#{@asset.public_path}"
      end

      it "generates #s3_path for thumbnail" do
        @asset.s3_url(:foo).should == "#{@asset.s3_task.protocol}#{@asset.s3_task.hostname}#{@asset.s3_task.port_string}/#{@asset.s3_task.bucket_name}#{@asset.public_path(:foo)}"
      end
    end

    before do
      pending "setup spec/s3.yml to run this spec" unless s3_loaded?
    end

    def s3_loaded?
      S3TaskAsset.attachment_tasks[:s3].config
    end

    def uploaded(asset)
      asset.id = 1000
      asset.stub!(:new_record?).and_return(false)
      asset
    end
    
    after :all do
      S3TaskAsset.drop_spec_env if s3_loaded?
      FileUtils.rm_rf AttachmentFu.root_path
    end
  end
end