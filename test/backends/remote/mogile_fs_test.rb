require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))

class MogileFSTest < ActiveSupport::TestCase
  def self.test_S3?
    true unless ENV["TEST_MOGILE"] == "false"
  end
  
  if test_S3? && File.exist?(File.join(File.dirname(__FILE__), '../../mogilefs.yml'))
    include BaseAttachmentTests
    attachment_model MogileFSAttachment

    def test_should_save_attachment(klass = MogileFSAttachment)
      attachment_model klass
      assert_created do
        attachment = upload_file :filename => '/files/rails.png'
        assert_valid attachment
        assert attachment.image?
        assert !attachment.size.zero?
      end
    end

    test_against_subclass :test_should_save_attachment, MogileFSAttachment

    def test_should_delete_attachment_from_mogile_when_attachment_record_destroyed(klass = MogileFSAttachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'

      attachment.destroy
      assert_raise(MogileFS::Backend::UnknownKeyError) do
        attachment.current_data
      end
    end

    test_against_subclass :test_should_delete_attachment_from_mogile_when_attachment_record_destroyed, MogileFSAttachment

  else
    def test_flunk_mogile
      puts "mogilefs config file not loaded, tests not running"
    end
  end
end
