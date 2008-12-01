require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe AttachmentFu::Pixels::MojoMagick do
  before :all do
    FileUtils.mkdir_p AttachmentFu.root_path
    @samples = File.join(File.dirname(__FILE__), 'samples')
    @pixels  = AttachmentFu::Tasks::Resize.new Class, :with => :mojo_magick
  end
    
  after :all do
    FileUtils.rm_rf AttachmentFu.root_path
  end
  
  describe "(for JPG)" do
    before do
      @attachment = mock("Attachment")
      @attachment.stub!(:full_path).and_return(File.join(@samples, 'casshern.jpg'))
    end

    it "gets accurate dimensions" do
      @pixels.with_image(nil, @attachment) do |image|
        ::MojoMagick.get_image_size(image).should == {:width => 80, :height => 75}
      end
    end
    
    it "resizes image with geometry string" do
      @pixels.with_image(nil, @attachment) do |image|
        data = @pixels.resize_image nil, image, :size => '40x40', :to => File.join(AttachmentFu.root_path, 'resized.jpg')
        data.width.should  == 40
        data.height.should == 38
        data.size.should satisfy { |s| s > 0 }
      end
    end
    
    it "resizes image with integer" do
      @pixels.with_image(nil, @attachment) do |image|
        data = @pixels.resize_image nil, image, :size => 40, :to => File.join(AttachmentFu.root_path, 'resized.jpg')
        data.width.should  == 40
        data.height.should == 38
        data.size.should satisfy { |s| s > 0 }
      end
    end
    
    it "resizes image with array" do
      @pixels.with_image(nil, @attachment) do |image|
        data = @pixels.resize_image nil, image, :size => [40, 40], :to => File.join(AttachmentFu.root_path, 'resized.jpg')
        data.width.should  == 40
        data.height.should == 38
        data.size.should satisfy { |s| s > 0 }
      end
    end
  end
end