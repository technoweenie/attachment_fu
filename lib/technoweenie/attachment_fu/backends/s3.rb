module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # = AWS::S3 Storage Backend
      #
      # Enables use of Amazon's Simple Storage Service (http://aws.amazon.com/s3) as a storage mechanism
      #
      # == Requirements
      #
      # Requires the AWS::S3 Library for S3 by Marcel Molina Jr. (http://amazon.rubyforge.org) installed either
      # as a gem or a as a Rails plugin.
      #
      # == Configuration
      #
      # Configuration is done via <tt>RAILS_ROOT/config/amazon_s3.yml</tt> and is loaded according to the <tt>RAILS_ENV</tt>.
      # The minimum connection options that you must specify are your access key id and your secret access key.
      # If you don't already have your access keys, all you need to sign up for the S3 service is an account at Amazon.
      # You can sign up for S3 and get access keys by visiting http://aws.amazon.com/s3.
      # 
      # Example configuration (RAILS_ROOT/config/amazon_s3.yml)
      # 
      #   development:
      #     secret_access_key: AbCDEfGHiJKlmNOPQRS1
      #     access_key_id: 1234567891abcdeFGHI/JKL+MnoPQrsT123UvwX4
      #     bucket_prefix: appname_development
      #   
      #   test:
      #     secret_access_key: AbCDEfGHiJKlmNOPQRS1
      #     access_key_id: 1234567891abcdeFGHI/JKL+MnoPQrsT123UvwX4
      #     bucket_prefix: appname_test
      #   
      #   production:
      #     secret_access_key: AbCDEfGHiJKlmNOPQRS1
      #     access_key_id: 1234567891abcdeFGHI/JKL+MnoPQrsT123UvwX4
      #     bucket_prefix: appname
      #
      # === Required arguments
      #
      # * <tt>:access_key_id</tt> - The access key id for your S3 account. Provided by Amazon.
      # * <tt>:secret_access_key</tt> - The secret access key for your S3 account. Provided by Amazon.
      # * <tt>:bucket_prefix</tt> - The string prefix to assign to each bucket. Used to create unique bucket names in the format <tt>#{bucket_prefix}_#{table_name}</tt>.
      #
      # If any of these required arguments is missing, a MissingAccessKey exception will be raised from AWS::S3.
      #
      # === Optional arguments
      #
      # * <tt>:server</tt> - The server to make requests to. You can use this to specify your bucket in the subdomain, or your own domain's cname if you are using virtual hosted buckets. Defaults to <tt>s3.amazonaws.com</tt>.
      # * <tt>:port</tt> - The port to the requests should be made on. Defaults to 80 or 443 if <tt>:use_ssl</tt> is set.
      # * <tt>:use_ssl</tt> - Whether requests should be made over SSL. If set to true, <tt>:port</tt> will be implicitly set to 443, unless specified otherwise. Defaults to false.
      #
      # == Usage
      #
      # To specify S3 as the storage mechanism for a model, set the acts_as_attachment <tt>:storage</tt> option to <tt>:s3</tt>.
      #
      #   class Photo < ActiveRecord::Base
      #     has_attachment :storage => :s3
      #   end
      #
      # Of course, all the usual configuration options apply:
      #
      #   has_attachment :storage => :s3, :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #   has_attachment :storage => :s3, :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
      module S3
        class S3RequiredLibraryNotFound < StandardError; end
        class S3ConfigFileNotFound < StandardError; end
        class S3BucketExists < StandardError; end

        def self.included(base) #:nodoc:
          base.attachment_options[:s3_access] ||= :public_read
          begin
            require 'aws/s3'
          rescue LoadError
            raise S3RequiredLibraryNotFound.new('AWS::S3 could not be loaded. Try installing with sudo gem i aws-s3, or see http://amazon.rubyforge.org for more information')
          end

          begin
            @@s3_config = YAML.load_file(RAILS_ROOT + '/config/amazon_s3.yml')[ENV['RAILS_ENV']].symbolize_keys
          rescue
            raise S3ConfigFileNotFound.new('File RAILS_ROOT/config/amazon_s3.yml not found')
          end

          @@bucket = [@@s3_config.delete(:bucket_prefix), base.table_name].join('_')
          mattr_reader :s3_config, :bucket

          AWS::S3::Base.establish_connection!(s3_config)
          find_or_create_bucket(bucket)

          base.before_update :rename_file
        end
      
        def self.find_or_create_bucket(name)
          AWS::S3::Bucket.find(name)
        rescue AWS::S3::NoSuchBucket
          AWS::S3::Bucket.create(name)
        rescue AWS::S3::AccessDenied
          raise S3BucketExists.new("Bucket name already exists: #{name}. Use a different bucket_prefix in RAILS_ROOT/config/amazon_s3.yml")
        end

        # Generates an S3 URL for the file in the form of: http(s)://<tt>{server}</tt>/<tt>{bucket_name}</tt>/<tt>{file_name}</tt>
        # The <tt>{server}</tt> variable defaults to <tt>AWS::S3 URL::DEFAULT_HOST</tt> (http://s3.amazonaws.com) and can be
        # set using the configuration parameters in <tt>RAILS_ROOT/config/amazon_s3.yml</tt>
        #
        # Example usage: <tt>image_tag(@photo.s3_url)</tt>
        def s3_url(thumbnail = nil)
          s3_config[:use_ssl] ? 'https://' : 'http://' + (s3_config[:server] || AWS::S3::DEFAULT_HOST) + '/' + bucket + '/' + thumbnail_name_for(thumbnail)
        end
        alias :public_filename :s3_url

        def create_temp_file
          write_to_temp_file current_data
        end

        protected
          # Destroys the file.  Called in the after_destroy callback
          def destroy_file
            AWS::S3::S3Object.delete filename, bucket
          end
          
          def rename_file
            return unless @old_filename && @old_filename != filename
            AWS::S3::S3Object.rename(@old_filename, filename, bucket, :access => :public_read)
            @old_filename = nil
            true
          end
          
          # Saves the file to S3
          def save_to_storage
            AWS::S3::S3Object.store(filename, attachment_data, bucket, :content_type => content_type, :access => attachment_options[:s3_access]) if save_attachment?
            @old_filename = nil
            true
          end
          
          def current_data
            AWS::S3::S3Object.value filename, bucket
          end
      end
    end
  end
end