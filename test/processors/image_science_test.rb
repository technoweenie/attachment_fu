require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class ImageScienceTest < Test::Unit::TestCase
  attachment_model ImageScienceAttachment

  def test_should_resize_image
    attachment = upload_file :filename => '/files/rails.png'
    assert_valid attachment
    assert attachment.image?
    assert_equal 43, attachment.width
    assert_equal 55, attachment.height
    
    thumb      = attachment.thumbnails.detect { |t| t.filename =~ /_thumb/ }
    geo        = attachment.thumbnails.detect { |t| t.filename =~ /_geometry/ }
    width      = attachment.thumbnails.detect { |t| t.filename =~ /_width/ }
    
    assert_equal 39, thumb.width
    assert_equal 50, thumb.height

    assert_equal 41, geo.width
    assert_equal 53, geo.height

    assert_equal 31, width.width
    assert_equal 40, width.height
  end
end