module BaseAttachmentTests
  def test_should_create_file_from_uploaded_file
    assert_created do
      attachment = upload_file :filename => '/files/foo.txt'
      assert_valid attachment
      assert !attachment.db_file.new_record? if attachment.respond_to?(:db_file)
      assert  attachment.image?
      assert !attachment.size.zero?
      #assert_equal 3, attachment.size
      assert_nil      attachment.width
      assert_nil      attachment.height
    end
  end
  
  def test_reassign_attribute_data
    assert_created 1 do
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.attachment_data.size > 0, "no data was set"
      
      attachment.attachment_data = 'wtf'
      attachment.save
      
      assert_equal 'wtf', attachment_model.find(attachment.id).attachment_data
    end
  end
  
  def test_no_reassign_attribute_data_on_nil
    assert_created 1 do
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment
      assert attachment.attachment_data.size > 0, "no data was set"
      
      attachment.attachment_data = nil
      assert !attachment.save_attachment?
    end
  end
  
  def test_should_overwrite_old_contents_when_updating
    attachment   = upload_file :filename => '/files/rails.png'
    assert_not_created do # no new db_file records
      attachment.filename        = 'rails2.png'
      attachment.attachment_data = IO.read(File.join(Test::Unit::TestCase.fixture_path, 'files', 'rails.png'))
      attachment.save
    end
  end
end