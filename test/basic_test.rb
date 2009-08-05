require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class BasicTest < Test::Unit::TestCase
  def test_should_set_default_min_size
    assert_equal 1, Attachment.attachment_options[:min_size]
  end

  def test_should_set_default_max_size
    assert_equal 1.megabyte, Attachment.attachment_options[:max_size]
  end

  def test_should_set_default_size
    assert_equal (1..1.megabyte), Attachment.attachment_options[:size]
  end

  def test_should_set_default_thumbnails_option
    assert_equal Hash.new, Attachment.attachment_options[:thumbnails]
  end

  def test_should_set_default_thumbnail_class
    assert_equal Attachment, Attachment.attachment_options[:thumbnail_class]
  end

  def test_should_normalize_content_types_to_array
    assert_equal %w(pdf), PdfAttachment.attachment_options[:content_type]
    assert_equal %w(pdf doc txt), DocAttachment.attachment_options[:content_type]
    assert_equal Technoweenie::AttachmentFu.content_types, ImageAttachment.attachment_options[:content_type]
    assert_equal ['pdf'] + Technoweenie::AttachmentFu.content_types, ImageOrPdfAttachment.attachment_options[:content_type]
  end

  def test_should_sanitize_content_type
    @attachment = Attachment.new :content_type => ' foo '
    assert_equal 'foo', @attachment.content_type
  end

  def test_should_sanitize_filenames
    @attachment = Attachment.new :filename => 'blah/foo.bar'
    assert_equal 'foo.bar',    @attachment.filename

    @attachment.filename = 'blah\\foo.bar'
    assert_equal 'foo.bar',    @attachment.filename

    @attachment.filename = 'f o!O-.bar'
    assert_equal 'f_o_O-.bar', @attachment.filename

    @attachment.filename = 'sheeps_says_bææ'
    assert_equal 'sheeps_says_b__', @attachment.filename

    @attachment.filename = nil
    assert_nil @attachment.filename
  end

  def test_should_convert_thumbnail_name
    @attachment = FileAttachment.new :filename => 'foo.bar'
    assert_equal 'foo.bar',           @attachment.thumbnail_name_for(nil)
    assert_equal 'foo.bar',           @attachment.thumbnail_name_for('')
    assert_equal 'foo_blah.bar',      @attachment.thumbnail_name_for(:blah)
    assert_equal 'foo_blah.blah.bar', @attachment.thumbnail_name_for('blah.blah')

    @attachment.filename = 'foo.bar.baz'
    assert_equal 'foo.bar_blah.baz', @attachment.thumbnail_name_for(:blah)
  end

  def test_should_require_valid_thumbnails_option
    klass = Class.new(ActiveRecord::Base)
    assert_raise ArgumentError do
      klass.has_attachment :thumbnails => []
    end
  end

  class ::ImageWithPolymorphicThumbsAttachment
    cattr_accessor :thumbnail_creations

    def create_or_update_thumbnail(path, thumb, *size)
      @@thumbnail_creations[thumb] = size.size == 1 ? size.first : size
    end

    def self.reset_creations
      @@thumbnail_creations = {}
    end
  end

  def test_should_handle_polymorphic_thumbnails_option
    assert_polymorphic_thumb_creation nil,
      :thumb => [50, 50], :geometry => 'x50'
    assert_polymorphic_thumb_creation 'Product',
      :thumb => [50, 50], :geometry => 'x50', :large_thumb => '169x169!', :zoomed => '500x500>'
    assert_polymorphic_thumb_creation 'Editorial',
      :thumb => [50, 50], :geometry => 'x50', :fullsize => '150x100>'
    assert_polymorphic_thumb_creation 'User',
      :thumb => [50, 50], :geometry => 'x50', :avatar => '64x64!'
  end

private
  def assert_polymorphic_thumb_creation(parent, defs)
    attachment_model ImageWithPolymorphicThumbsAttachment
    attachment_model.reset_creations
    attachment = upload_file :filename => '/files/rails.png', :imageable_type => parent.to_s.classify, :imageable_id => nil
    assert_equal defs, attachment_model.thumbnail_creations
  end
end
