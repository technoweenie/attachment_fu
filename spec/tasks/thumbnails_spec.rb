require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module AttachmentFu
  class ThumbnailsTaskAsset < ActiveRecord::Base
    is_faux_attachment do
      task :thumbnails, :sizes => {:small => '40x40', :tiny => '10x10'}
    end
  end
  
  describe "Thumbnails Task" do
    before :all do
      @samples  = File.join(File.dirname(__FILE__), 'pixels', 'samples')
      @original = File.join(@samples, 'casshern.jpg')
      @sample   = File.join(@samples, 'sample.jpg')
    end

    before do
      FileUtils.cp @original, @sample
      @asset = ThumbnailsTaskAsset.new :content_type => 'image/jpg'
      @asset.set_temp_path @sample
      @asset.save!
    end

    it "saves attachment" do
      File.exist? @asset.full_path
    end

    it "creates correct number of thumbnails with matching thumbnail keys" do
      @asset.should have(2).thumbnails
      @asset.thumbnails.sort_by { |t| t.thumbnail }.map(&:thumbnail).should == %w(small tiny)
    end

    it "keeps the attachment's original width" do
      @asset.width.should == 80
    end

    it "resizes thumbnails to the resized width" do
      @asset.thumbnails.each do |thumb|
        thumb.width.should  == (thumb.thumbnail == 'small' ? 40 : 10)
      end
    end

    before :all do
      ThumbnailsTaskAsset.setup_spec_env
    end
    
    after :all do
      ThumbnailsTaskAsset.drop_spec_env
      FileUtils.rm_rf AttachmentFu.root_path
    end
  end
end