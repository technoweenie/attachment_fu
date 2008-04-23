require File.dirname(__FILE__) + '/../../spec_helper'

describe AttachmentFu::Pixels::CoreImage do
  before :all do
    FileUtils.mkdir_p AttachmentFu.root_path
    @samples = File.join(File.dirname(__FILE__), 'samples')
    @pixels  = AttachmentFu::Tasks::Resize.new Class, :with => :core_image
  end
    
  after :all do
    FileUtils.rm_rf AttachmentFu.root_path
  end
  
  describe "(for JPG)" do
    before do
      @attachment = mock("Attachment")
      @attachment.stub!(:full_filename).and_return(File.join(@samples, 'casshern.jpg'))
    end

    it "gets accurate dimensions" do
      @pixels.with_image(@attachment) do |image|
        image.extent.size.width.should  == 80
        image.extent.size.height.should == 75
      end
    end
    
    it "resizes image with geometry string" do
      @pixels.with_image(@attachment) do |image|
        data = @pixels.resize_image image, :size => '40x40', :to => File.join(AttachmentFu.root_path, 'resized.jpg')
        data.width.should  == 40
        data.height.should == 38
        data.size.should satisfy { |s| s > 0 }
      end
    end
    
    it "resizes image with integer" do
      @pixels.with_image(@attachment) do |image|
        data = @pixels.resize_image image, :size => 40, :to => File.join(AttachmentFu.root_path, 'resized.jpg')
        data.width.should  == 40
        data.height.should == 37
        data.size.should satisfy { |s| s > 0 }
      end
    end
    
    it "resizes image with array" do
      @pixels.with_image(@attachment) do |image|
        data = @pixels.resize_image image, :size => [40, 40], :to => File.join(AttachmentFu.root_path, 'resized.jpg')
        data.width.should  == 40
        data.height.should == 40
        data.size.should satisfy { |s| s > 0 }
      end
    end
  end
end