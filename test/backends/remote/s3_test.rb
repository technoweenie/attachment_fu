require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'net/http'
require 'open-uri'

class S3Test < ActiveSupport::TestCase
  def self.test_S3?
    true unless ENV["TEST_S3"] == "false"
  end

  CONFIG_FILE = File.join(File.dirname(__FILE__), '../../amazon_s3.yml')

  if test_S3? && File.exist?(CONFIG_FILE)
    include BaseAttachmentTests
    attachment_model S3Attachment

    def test_should_create_correct_bucket_name(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal attachment.s3_config[:bucket_name], attachment.bucket_name
    end

    test_against_subclass :test_should_create_correct_bucket_name, S3Attachment

    def test_should_create_default_path_prefix(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      # TODO path_prefix, amonth other options, bleed between instances and subclasses.
      #assert_equal File.join(attachment_model.table_name, attachment.attachment_path_id), attachment.base_path
    end

    test_against_subclass :test_should_create_default_path_prefix, S3Attachment

    def test_should_create_custom_path_prefix(klass = S3WithPathPrefixAttachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal File.join('some/custom/path/prefix', attachment.attachment_path_id), attachment.base_path
    end

    test_against_subclass :test_should_create_custom_path_prefix, S3WithPathPrefixAttachment

    def test_should_create_valid_url(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_equal "#{attachment.s3_protocol}#{attachment.s3_hostname}:#{attachment.s3_port_string}/#{attachment.bucket_name}/#{attachment.full_filename}", attachment.s3_url
    end

    test_against_subclass :test_should_create_valid_url, S3Attachment

    def test_should_create_authenticated_url(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      assert_match /^http.+AWSAccessKeyId.+Expires.+Signature.+/, attachment.authenticated_s3_url(:use_ssl => true)
    end

    test_against_subclass :test_should_create_authenticated_url, S3Attachment
    
    def test_should_create_authenticated_url_for_thumbnail(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'
      ['large', :large].each do |thumbnail|
        assert_match(
          /^http.+rails_large\.png.+AWSAccessKeyId.+Expires.+Signature/, 
          attachment.authenticated_s3_url(thumbnail), 
          "authenticated_s3_url failed with #{thumbnail.class} parameter"
        )
      end
    end

    def test_should_save_attachment(klass = S3Attachment)
      attachment_model klass
      assert_created do
        attachment = upload_file :filename => '/files/rails.png'
        assert_valid attachment
        assert attachment.image?
        assert !attachment.size.zero?

        # TODO
        # how did this ever pass?
        # attachments in attachment_fu are :private by default and this is an unauthenticated url?
        #
        # I verified that it is just an acl issue on the generated object.
        # attachment_fu has an s3_access option but doesn't work in these tests, if at all.
        #assert_kind_of Net::HTTPOK, http_response_for(attachment.s3_url)
      end
    end

    test_against_subclass :test_should_save_attachment, S3Attachment

    def test_authenticated_url
      attachment = upload_file :filename => '/files/rails.png'
      assert_valid attachment

      url = attachment.authenticated_s3_url(:use_ssl => true, :expires_in => 1.hour)
      assert URI.parse(url).read.size > 0
    end

    def test_should_delete_attachment_from_s3_when_attachment_record_destroyed(klass = S3Attachment)
      attachment_model klass
      attachment = upload_file :filename => '/files/rails.png'

      urls = [attachment.s3_url] + attachment.thumbnails.collect(&:s3_url)

      # TODO another case of accessing a private url anonymously
      # see below comment on s3_access and these tests.
      #urls.each {|url| assert_kind_of Net::HTTPOK, http_response_for(url) }
      attachment.destroy
      urls.each do |url|
        begin
          http_response_for(url)
        rescue Net::HTTPForbidden, Net::HTTPNotFound
          nil
        end
      end
    end

    test_against_subclass :test_should_delete_attachment_from_s3_when_attachment_record_destroyed, S3Attachment

    protected
      def http_response_for(url)
        url = URI.parse(url)
        Net::HTTP.start(url.host, url.port, :use_ssl => true ) {|http| http.request_head(url.path) }
      end
      
  else
    def test_flunk_s3
      puts "s3 tests disabled by environment" unless self.class.test_S3?
      puts "s3 test config doesn't exist" unless File.exist?(CONFIG_FILE)
      puts "s3 config file not loaded, tests not running"
    end
  end
end
