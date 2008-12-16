require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module AttachmentFu
  class S3TaskAsset < ActiveRecord::Base
    begin
      is_faux_attachment do
        task :s3, :bucket_name => "attachment_fu_s3_test"
      end
    rescue AWS::S3::MissingAccessKey
    end

    after_update  :rename_s3_object
    after_destroy :delete_s3_object

  protected
    def rename_s3_object
      s3.rename
    end

    def delete_s3_object
      s3.delete
    end
  end

  describe "S3 Asset" do
    before :all do
      S3TaskAsset.setup_spec_env if s3_loaded?
      @samples  = File.join(File.dirname(__FILE__), 'pixels', 'samples')
      @original = File.join(@samples, 'casshern.jpg')
      @sample   = File.join(@samples, 'sample.jpg')
    end

    describe "being created" do
      before :all do
        if s3_loaded?
          FileUtils.cp @original, @sample
          @asset = S3TaskAsset.new :content_type => 'image/jpg'
          @asset.set_temp_path @sample
        end
      end

      describe "with default options" do
        before :all do
          @asset.save!
        end

        it "generates #s3.path" do
          "/#{@asset.s3.path}".should == @asset.public_path
        end

        it "generates #s3.url" do
          @asset.s3.url.should == "#{@asset.s3.task.protocol}#{@asset.s3.task.hostname}#{@asset.s3.task.port_string}/#{@asset.s3.task.bucket_name}#{@asset.public_path}"
        end

        it "generates #s3.url for thumbnail" do
          @asset.s3.url(:foo).should == "#{@asset.s3.task.protocol}#{@asset.s3.task.hostname}#{@asset.s3.task.port_string}/#{@asset.s3.task.bucket_name}#{@asset.public_path(:foo)}"
        end

        it "uploads asset to s3" do
          @asset.s3.object_exists?.should == true
        end

        it "uploads asset to s3 with default access of " do
          @asset.s3.object_exists?.should == true
        end

        it "deletes asset filename from local filesystem" do
          File.exist?(@asset.full_path).should == false
        end

        it "#s3.object retrieves meta data" do
          @asset.s3.object.content_type.should == @asset.content_type
          @asset.s3.object.size.should         == @asset.size
        end

        it "#s3.stream streams object data" do
          begin
            t = Tempfile.new("s3streamtest")
            @asset.s3.stream do |chunk|
              t.write chunk
            end
            t.close
            File.size(t.path).should == @asset.size
          rescue EOFError
            pending "AWS::S3 streaming seems to be busted: #{$!.to_s}"
          end
        end
      end

      describe "with custom access settings" do
        before do
          @task = S3TaskAsset.attachment_tasks[:s3]
          FileUtils.cp @original, @sample
          @asset = S3TaskAsset.new :content_type => 'image/jpg'
          @asset.set_temp_path @sample
        end

        it "uploads with default :access == :authenticated_read" do
          @task.options.delete(:access)
          AWS::S3::S3Object.should_receive(:store).with(anything, anything, anything, :content_type => @asset.content_type, :access => :authenticated_read)
          @asset.save
        end

        it "uploads with custom :access" do
          @task.options[:access] = :public_read
          AWS::S3::S3Object.should_receive(:store).with(anything, anything, anything, :content_type => @asset.content_type, :access => :public_read)
          @asset.save
        end

        it "uploads with proc :access" do
          @task.options[:access] = lambda { |a| a.is_a?(S3TaskAsset) ? :private : :invalid_argument }
          AWS::S3::S3Object.should_receive(:store).with(anything, anything, anything, :content_type => @asset.content_type, :access => :private)
          @asset.save
        end
      end
    end

    describe "being renamed" do
      before :all do
        if s3_loaded?
          FileUtils.cp @original, @sample
          @asset = S3TaskAsset.new :content_type => 'image/jpg'
          @asset.set_temp_path @sample
          @asset.save!
          @old_path = @asset.s3.path
          @asset.filename = 'sampler.jpg'
          @asset.save!
        end
      end

      it "removes traces of old asset" do
        AWS::S3::S3Object.exists?(@old_path, @asset.s3.task.options[:bucket_name]).should == false
      end

      it "moves contest to new asset" do
        AWS::S3::S3Object.exists?(@asset.s3.path, @asset.s3.task.options[:bucket_name]).should == true
      end
    end

    describe "being deleted" do
      before :all do
        if s3_loaded?
          FileUtils.cp @original, @sample
          @asset = S3TaskAsset.new :content_type => 'image/jpg'
          @asset.set_temp_path @sample
          @asset.save!
          @asset.destroy
        end
      end

      it "removes traces of asset" do
        @asset.s3.object_exists?.should == false
      end
    end

    before do
      pending "setup spec/config.rb to run this spec" unless s3_loaded?
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