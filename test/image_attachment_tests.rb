module ImageAttachmentTests
  def test_should_create_image_from_uploaded_file
    assert_created do
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
      #assert_equal 1784, attachment.size
      assert_equal 50,   attachment.width
      assert_equal 64,   attachment.height
      assert_equal '50x64', attachment.image_size
    end
  end

  def test_should_create_image_from_uploaded_file_with_custom_content_type
    assert_created do
      attachment = upload_file :content_type => 'foo/bar', :filename => '/files/rails.png'
      assert_valid attachment
      assert !attachment.image?
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert !attachment.size.zero?
      #assert_equal 1784, attachment.size
      assert_nil attachment.width
      assert_nil attachment.height
      assert_equal [], attachment.thumbnails
    end
  end
  
  def test_should_create_thumbnail
    attachment = upload_file :filename => '/files/rails.png'
    
    assert_created do
      basename, ext = attachment.filename.split '.'
      thumbnail = attachment.create_or_update_thumbnail(attachment.create_temp_file, 'thumb', 50, 50)
      assert_valid thumbnail
      assert !thumbnail.size.zero?
      #assert_in_delta 4673, thumbnail.size, 2
      assert_equal 50,   thumbnail.width
      assert_equal 50,   thumbnail.height
      assert_equal [thumbnail.id], attachment.thumbnails.collect(&:id)
      assert_equal attachment.id,  thumbnail.parent_id if thumbnail.respond_to?(:parent_id)
      assert_equal "#{basename}_thumb.#{ext}", thumbnail.filename
    end
  end
  
  def test_should_create_thumbnail_with_geometry_string
    attachment = upload_file :filename => '/files/rails.png'
    
    assert_created do
      basename, ext = attachment.filename.split '.'
      thumbnail = attachment.create_or_update_thumbnail(attachment.create_temp_file, 'thumb', 'x50')
      assert_valid thumbnail
      assert !thumbnail.size.zero?
      #assert_equal 3915, thumbnail.size
      assert_equal 39,   thumbnail.width
      assert_equal 50,   thumbnail.height
      assert_equal [thumbnail], attachment.thumbnails
      assert_equal attachment.id,  thumbnail.parent_id if thumbnail.respond_to?(:parent_id)
      assert_equal "#{basename}_thumb.#{ext}", thumbnail.filename
    end
  end
end