module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # = AWS::S3 Storage Backend
      #
      # Enables use of {Amazon's Simple Storage Service}[http://aws.amazon.com/s3] as a storage mechanism
      #
      # == Requirements
      #
      # Requires the {AWS::S3 Library}[http://amazon.rubyforge.org] for S3 by Marcel Molina Jr. installed either
      # as a gem or a as a Rails plugin.
      #
      # == Configuration
      #
      # Configuration is done via <tt>RAILS_ROOT/config/amazon_s3.yml</tt> and is loaded according to the <tt>RAILS_ENV</tt>.
      # The minimum connection options that you must specify are a bucket name, your access key id and your secret access key.
      # If you don't already have your access keys, all you need to sign up for the S3 service is an account at Amazon.
      # You can sign up for S3 and get access keys by visiting http://aws.amazon.com/s3.
      #
      # If you wish to use Amazon CloudFront to serve the files, you can also specify a distibution domain for the bucket.
      # To read more about CloudFront, visit http://aws.amazon.com/cloudfront
      #
      # Example configuration (RAILS_ROOT/config/amazon_s3.yml)
      #
      #   development:
      #     bucket_name: appname_development
      #     access_key_id: <your key>
      #     secret_access_key: <your key>
      #     distribution_domain: XXXX.cloudfront.net
      #
      #   test:
      #     bucket_name: appname_test
      #     access_key_id: <your key>
      #     secret_access_key: <your key>
      #     distribution_domain: XXXX.cloudfront.net
      #
      #   production:
      #     bucket_name: appname
      #     access_key_id: <your key>
      #     secret_access_key: <your key>
      #     distribution_domain: XXXX.cloudfront.net
      #
      # You can change the location of the config path by passing a full path to the :s3_config_path option.
      #
      #   has_attachment :storage => :s3, :s3_config_path => (RAILS_ROOT + '/config/s3.yml')
      #
      # === Required configuration parameters
      #
      # * <tt>:access_key_id</tt> - The access key id for your S3 account. Provided by Amazon.
      # * <tt>:secret_access_key</tt> - The secret access key for your S3 account. Provided by Amazon.
      # * <tt>:bucket_name</tt> - A unique bucket name (think of the bucket_name as being like a database name).
      #
      # If any of these required arguments is missing, a MissingAccessKey exception will be raised from AWS::S3.
      #
      # == About bucket names
      #
      # Bucket names have to be globaly unique across the S3 system. And you can only have up to 100 of them,
      # so it's a good idea to think of a bucket as being like a database, hence the correspondance in this
      # implementation to the development, test, and production environments.
      #
      # The number of objects you can store in a bucket is, for all intents and purposes, unlimited.
      #
      # === Optional configuration parameters
      #
      # * <tt>:server</tt> - The server to make requests to. Defaults to <tt>s3.amazonaws.com</tt>.
      # * <tt>:port</tt> - The port to the requests should be made on. Defaults to 80 or 443 if <tt>:use_ssl</tt> is set.
      # * <tt>:use_ssl</tt> - If set to true, <tt>:port</tt> will be implicitly set to 443, unless specified otherwise. Defaults to false.
      # * <tt>:distribution_domain</tt> - The CloudFront distribution domain for the bucket.  This can either be the assigned
      #     distribution domain (ie. XXX.cloudfront.net) or a chosen domain using a CNAME. See CloudFront for more details.
      #
      # == Usage
      #
      # To specify S3 as the storage mechanism for a model, set the acts_as_attachment <tt>:storage</tt> option to <tt>:s3</tt>.
      #
      #   class Photo < ActiveRecord::Base
      #     has_attachment :storage => :s3
      #   end
      #
      # === Customizing the path
      #
      # By default, files are prefixed using a pseudo hierarchy in the form of <tt>:table_name/:id</tt>, which results
      # in S3 urls that look like: http(s)://:server/:bucket_name/:table_name/:id/:filename with :table_name
      # representing the customizable portion of the path. You can customize this prefix using the <tt>:path_prefix</tt>
      # option:
      #
      #   class Photo < ActiveRecord::Base
      #     has_attachment :storage => :s3, :path_prefix => 'my/custom/path'
      #   end
      #
      # Which would result in URLs like <tt>http(s)://:server/:bucket_name/my/custom/path/:id/:filename.</tt>
      #
      # === Using different bucket names on different models
      #
      # By default the bucket name that the file will be stored to is the one specified by the
      # <tt>:bucket_name</tt> key in the amazon_s3.yml file.  You can use the <tt>:bucket_key</tt> option
      # to overide this behavior on a per model basis.  For instance if you want a bucket that will hold
      # only Photos you can do this:
      #
      #   class Photo < ActiveRecord::Base
      #     has_attachment :storage => :s3, :bucket_key => :photo_bucket_name
      #   end
      #
      # And then your amazon_s3.yml file needs to look like this.
      #
      #   development:
      #     bucket_name: appname_development
      #     access_key_id: <your key>
      #     secret_access_key: <your key>
      #
      #   test:
      #     bucket_name: appname_test
      #     access_key_id: <your key>
      #     secret_access_key: <your key>
      #
      #   production:
      #     bucket_name: appname
      #     photo_bucket_name: appname_photos
      #     access_key_id: <your key>
      #     secret_access_key: <your key>
      #
      #  If the bucket_key you specify is not there in a certain environment then attachment_fu will
      #  default to the <tt>bucket_name</tt> key.  This way you only have to create special buckets
      #  this can be helpful if you only need special buckets in certain environments.
      #
      # === Permissions
      #
      # By default, files are stored on S3 with public access permissions. You can customize this using
      # the <tt>:s3_access</tt> option to <tt>has_attachment</tt>. Available values are
      # <tt>:private</tt>, <tt>:public_read_write</tt>, and <tt>:authenticated_read</tt>.
      #
      # === Other options
      #
      # Of course, all the usual configuration options apply, such as content_type and thumbnails:
      #
      #   class Photo < ActiveRecord::Base
      #     has_attachment :storage => :s3, :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #     has_attachment :storage => :s3, :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
      #   end
      #
      # === Accessing S3 URLs
      #
      # You can get an object's URL using the s3_url accessor. For example, assuming that for your postcard app
      # you had a bucket name like 'postcard_world_development', and an attachment model called Photo:
      #
      #   @postcard.s3_url # => http(s)://s3.amazonaws.com/postcard_world_development/photos/1/mexico.jpg
      #
      # The resulting url is in the form: http(s)://:server/:bucket_name/:table_name/:id/:file.
      # The optional thumbnail argument will output the thumbnail's filename (if any).
      #
      # Additionally, you can get an object's base path relative to the bucket root using
      # <tt>base_path</tt>:
      #
      #   @photo.file_base_path # => photos/1
      #
      # And the full path (including the filename) using <tt>full_filename</tt>:
      #
      #   @photo.full_filename # => photos/
      #
      # Niether <tt>base_path</tt> or <tt>full_filename</tt> include the bucket name as part of the path.
      # You can retrieve the bucket name using the <tt>bucket_name</tt> method.
      #
      # === Accessing CloudFront URLs
      #
      # You can get an object's CloudFront URL using the cloudfront_url accessor.  Using the example from above:
      # @postcard.cloudfront_url # => http://XXXX.cloudfront.net/photos/1/mexico.jpg
      #
      # The resulting url is in the form: http://:distribution_domain/:table_name/:id/:file
      #
      # If you set :cloudfront to true in your model, the public_url will be the CloudFront
      # URL, not the S3 URL.
      class S3Backend < BackendDelegator
        class RequiredLibraryNotFoundError < StandardError; end
        class ConfigFileNotFoundError < StandardError; end

        attr_accessor :s3_config
        attr_reader :bucket_name
        
        @@s3_config_path = nil

        def initialize(obj, opts)
          # zendesk classic rails usage note
          # all the options from our attachments.yml come in through the opts argument here.
          super(obj, opts)

          if @@s3_config_path
            # config from file.
            self.s3_config = YAML.load(ERB.new(File.read(@@s3_config_path)).result)[ENV['RAILS_ENV']].symbolize_keys
          else
            # config entirely through initializer

            # a few options need renaming.
            opts[:access_key_id] = opts[:s3_access_key] if opts.has_key? :s3_access_key
            opts[:secret_access_key] = opts[:s3_secret_key] if opts.has_key? :s3_secret_key

            self.s3_config = opts
          end

          @bucket_name = self.s3_config[:bucket_name]

        end

        def self.included_in_base(base) #:nodoc:

          begin
            require 'aws-sdk'
          rescue LoadError
            raise RequiredLibraryNotFoundError.new('AWS::SDK could not be loaded')
          end

          if base.attachment_options[:s3_config_path]
            @@s3_config_path = base.attachment_options[:s3_config_path] || (RAILS_ROOT + '/config/amazon_s3.yml')
          end

        end

        def connection
          @s3 ||= AWS::S3.new(s3_config)
        end

        def protocol
          @protocol ||= s3_config[:use_ssl] ? 'https://' : 'http://'
        end

        def hostname
          connection.client.endpoint
        end

        def port_string
          connection.client.port.to_s
        end

        def distribution_domain
          @distribution_domain = s3_config[:distribution_domain]
        end
        def s3_protocol
          protocol
        end

        def s3_hostname
          hostname
        end

        def s3_port_string
          port_string
        end

        def cloudfront_distribution_domain
          distribution_domain
        end

        # called by the ActiveRecord class from filename=
        def notify_rename
          @old_filename = filename unless filename.nil? || @old_filename
        end

        # The attachment ID used in the full path of a file
        def attachment_path_id
          ((respond_to?(:parent_id) && parent_id) || @obj.id).to_s
        end

        # The pseudo hierarchy containing the file relative to the bucket name
        # Example: <tt>:table_name/:id</tt>
        def base_path
          File.join(attachment_options[:path_prefix], attachment_path_id)
        end

        # The full path to the file relative to the bucket name
        # Example: <tt>:table_name/:id/:filename</tt>
        def full_filename(thumbnail = nil)
          File.join(base_path, thumbnail_name_for(thumbnail))
        end

        # All public objects are accessible via a GET request to the S3 servers. You can generate a
        # url for an object using the s3_url method.
        #
        #   @photo.s3_url
        #
        # The resulting url is in the form: <tt>http(s)://:server/:bucket_name/:table_name/:id/:file</tt> where
        # the <tt>:server</tt> variable defaults to <tt>AWS::S3 URL::DEFAULT_HOST</tt> (s3.amazonaws.com) and can be
        # set using the configuration parameters in <tt>RAILS_ROOT/config/amazon_s3.yml</tt>.
        #
        # The optional thumbnail argument will output the thumbnail's filename (if any).
        def s3_url(thumbnail = nil)
          File.join(s3_protocol + s3_hostname + ':' + s3_port_string, bucket_name, full_filename(thumbnail))
        end

        # All public objects are accessible via a GET request to CloudFront. You can generate a
        # url for an object using the cloudfront_url method.
        #
        #   @photo.cloudfront_url
        #
        # The resulting url is in the form: <tt>http://:distribution_domain/:table_name/:id/:file</tt> using
        # the <tt>:distribution_domain</tt> variable set in the configuration parameters in <tt>RAILS_ROOT/config/amazon_s3.yml</tt>.
        #
        # The optional thumbnail argument will output the thumbnail's filename (if any).
        def cloudfront_url(thumbnail = nil)
          "http://" + s3_config[:distribution_domain] + "/" + full_filename(thumbnail)
        end

        def public_url(*args)
          if attachment_options[:cloudfront]
            cloudfront_url(args)
          else
            s3_url(args)
          end
        end

        # All private objects are accessible via an authenticated GET request to the S3 servers. You can generate an
        # authenticated url for an object like this:
        #
        #   @photo.authenticated_s3_url
        #
        # By default authenticated urls expire 5 minutes after they were generated.
        #
        # Expiration options can be specified either with an absolute time using the <tt>:expires</tt> option,
        # or with a number of seconds relative to now with the <tt>:expires_in</tt> option:
        #
        #   # Absolute expiration date (October 13th, 2025)
        #   @photo.authenticated_s3_url(:expires => Time.mktime(2025,10,13).to_i)
        #
        #   # Expiration in five hours from now
        #   @photo.authenticated_s3_url(:expires_in => 5.hours)
        #
        # You can specify whether the url should go over SSL with the <tt>:use_ssl</tt> option.
        # By default, the ssl settings for the current connection will be used:
        #
        #   @photo.authenticated_s3_url(:use_ssl => true)
        #
        # Finally, the optional thumbnail argument will output the thumbnail's filename (if any):
        #
        #   @photo.authenticated_s3_url('thumbnail', :expires_in => 5.hours, :use_ssl => true)
        def authenticated_s3_url(*args)
          options   = args.extract_options!
          options[:expires_in] = options[:expires_in].to_i if options[:expires_in]
          thumbnail = args.shift
          self.bucket.objects[full_filename(thumbnail)].url_for(:get,options).to_s
        end

        def bucket
          @bucket_c ||= connection.buckets[bucket_name]
        end

        def current_data
          bucket.objects[full_filename].read
        end

        # Called in the after_destroy callback
        def destroy_file
          bucket.objects[full_filename].delete
        rescue Errno::ECONNRESET
          retries ||= 0
          retries += 1
          retry if retries <= 1
        end

        def rename_file
          return unless @old_filename && @old_filename != filename

          old_full_filename = File.join(base_path, @old_filename)

          o = bucket.objects[full_filename]
          o.rename_to(old_full_filename)

          @old_filename = nil
          true
        end

        def save_to_storage
          if save_attachment?
            obj = bucket.objects[full_filename]
            if temp_path
              obj.write(:file => temp_path, :content_type => content_type, :server_side_encryption => :aes256)
            else
              obj.write(temp_data, :content_type => content_type, :server_side_encryption => :aes256)
            end
          end

          @old_filename = nil
          true
        end
      end
    end
  end
end
