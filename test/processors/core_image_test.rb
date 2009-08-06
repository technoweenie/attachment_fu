require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class CoreImageTest < Test::Unit::TestCase
  attachment_model CoreImageAttachment

  if Object.const_defined?(:OSX)
    def test_should_resize_image
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.image?
      # test core image thumbnail
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
      
      # This makes sure that we didn't overwrite the original file
      # and will end up with a thumbnail instead of the original
      assert_equal 42, attachment.width
      assert_equal 55, attachment.height
      
    end

    def test_should_handle_jpeg_quality
      attachment_model CoreImageAttachment
      attachment = upload_file :filename => '/files/rails.jpg', :content_type => 'image/jpeg'
      full_size = attachment.size
      attachment_model LowerQualityCoreImageAttachment
      attachment = upload_file :filename => '/files/rails.jpg', :content_type => 'image/jpeg'
      lq_size = attachment.size
      assert lq_size <= full_size * 0.9, 'Lower-quality JPEG filesize should be congruently smaller'

      # FIXME: wait for Marcus' reply to determine whether I can get exact-quality output or need to adjust for CoreImage.
      # attachment_model CoreImageWithPerThumbJpegAttachment
      # attachment = upload_file :filename => '/files/rails.jpg', :content_type => 'image/jpeg'
      # assert_file_jpeg_quality attachment, :thumb, 90
      # assert_file_jpeg_quality attachment, :avatar, 80
      # assert_file_jpeg_quality attachment, :editorial, 75
      # assert_file_jpeg_quality attachment, nil, 75
    end
  else
    def test_flunk
      puts "CoreImage not loaded, tests not running"
    end
  end
end