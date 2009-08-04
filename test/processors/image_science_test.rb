require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class ImageScienceTest < Test::Unit::TestCase
  attachment_model ImageScienceAttachment

  if Object.const_defined?(:ImageScience)
    def test_should_resize_image
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.image?
      # test image science thumbnail
      assert_equal 42, attachment.width
      assert_equal 55, attachment.height
      
      thumb      = attachment.thumbnails.detect { |t| t.filename =~ /_thumb/ }
      geo        = attachment.thumbnails.detect { |t| t.filename =~ /_geometry/ }
      aspect     = attachment.thumbnails.detect { |t| t.filename =~ /_aspect/ }
      
      # test exact resize dimensions
      assert_equal 50, thumb.width
      assert_equal 51, thumb.height
      
      # test geometry strings
      assert_equal 31, geo.width
      assert_equal 41, geo.height
      assert_equal 25, aspect.width
      assert_equal 25, aspect.height
    end
  else
    def test_flunk
      puts "ImageScience not loaded, tests not running"
    end
  end
end