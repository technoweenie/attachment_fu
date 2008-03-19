require File.dirname(__FILE__) + '/../spec_helper'

module AttachmentFu
  class ResizeTaskAsset < ActiveRecord::Base
    is_faux_attachment do
      task :resize, :to => '40x40'
    end
  end
  
  describe "Resize Task" do
    before :all do
      @samples  = File.join(File.dirname(__FILE__), 'pixels', 'samples')
      @original = File.join(@samples, 'casshern.jpg')
      @sample   = File.join(@samples, 'sample.jpg')
    end
    
    before do
      FileUtils.cp @original, @sample
      @asset = ResizeTaskAsset.create! :content_type => 'image/jpg', :temp_path => @sample
    end
    
    it "saves attachment" do
      File.exist? @asset.full_filename
    end
    
    it "resizes image" do
      @pixels  = AttachmentFu::Pixels.new :core_image, @asset.full_filename
      @pixels.with_image do |image|
        image.extent.size.width.should  == 40
        image.extent.size.height.should == 38
      end
    end

    before :all do
      ResizeTaskAsset.setup_spec_env
    end
    
    after :all do
      ResizeTaskAsset.drop_spec_env
      FileUtils.rm_rf AttachmentFu.root_path
    end
  end
end