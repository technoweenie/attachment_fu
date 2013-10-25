# encoding: utf-8
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class BasicTest < ActiveSupport::TestCase
  def test_should_set_default_min_size
    assert_equal 1, AttachmentTest.attachment_options[:min_size]
  end

  def test_should_set_default_max_size
    assert_equal 1.megabyte, AttachmentTest.attachment_options[:max_size]
  end

  def test_should_set_default_size
    assert_equal (1..1.megabyte), AttachmentTest.attachment_options[:size]
  end

  def test_should_set_default_thumbnails_option
    assert_equal Hash.new, AttachmentTest.attachment_options[:thumbnails]
  end

  def test_should_set_default_thumbnail_class
    assert_equal AttachmentTest, AttachmentTest.attachment_options[:thumbnail_class]
  end

  def test_should_normalize_content_types_to_array
    assert_equal %w(pdf), PdfAttachment.attachment_options[:content_type]
    assert_equal %w(pdf doc txt), DocAttachment.attachment_options[:content_type]
    assert_equal Technoweenie::AttachmentFu.content_types, ImageAttachment.attachment_options[:content_type]
    assert_equal ['pdf'] + Technoweenie::AttachmentFu.content_types, ImageOrPdfAttachment.attachment_options[:content_type]
  end

  def test_should_sanitize_content_type
    @attachment = AttachmentTest.new :content_type => ' foo '
    assert_equal 'foo', @attachment.content_type
  end

  def test_should_sanitize_filenames
    @attachment = AttachmentTest.new :filename => 'blah/foo.bar'
    assert_equal 'foo.bar',    @attachment.filename

    @attachment.filename = 'blah\\foo.bar'
    assert_equal 'foo.bar',    @attachment.filename

    @attachment.filename = 'f o!O-.bar'
    assert_equal 'f_o_O-.bar', @attachment.filename

    @attachment.filename = 'sheeps_says_bÒÔ'
    assert_match /sheeps_says_b__/, @attachment.filename

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
end
