require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class DbFileTest < ActiveSupport::TestCase
  include BaseAttachmentTests
  attachment_model AttachmentTest
end
