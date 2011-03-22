module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # = RightAws::S3 Storage Backend
      #
      # Enables use of {Amazon's Simple Storage Service}[http://aws.amazon.com/s3] as a storage mechanism
      #
      # == Requirements
      #
      # Requires the {RightAws Library}[http://http://rubyforge.org/projects/rightscale] for S3 by RightScale installed either
      # as a gem or as a Rails plugin.
      #
      # == Configuration
      #
      # Configuration is imported from the ApplicationConfig object (amazon_s3 method).
      #
      # === Required configuration parameters
      #
      # * <tt>:access_key_id</tt> - The access key id for your S3 account. Provided by Amazon.
      # * <tt>:secret_access_key</tt> - The secret access key for your S3 account. Provided by Amazon.
      # * <tt>:bucket_name</tt> - A unique bucket name (think of the bucket_name as being like a database name).
      #
      # == About bucket names
      #
      # Bucket names have to be globally unique across the S3 system. And you can only have up to 100 of them,
      # so it's a good idea to think of a bucket as being like a database, hence the correspondance in this
      # implementation to the development, test, and production environments.
      #
      # The number of objects you can store in a bucket is, for all intents and purposes, unlimited.
      #
      # == Usage
      #
      # To specify RightAws::S3 as the storage mechanism for a model, set the acts_as_attachment <tt>:storage</tt> option to <tt>:rights3</tt>.
      #
      #   class Photo < ActiveRecord::Base
      #     has_attachment :storage => :rights3
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
      #     has_attachment :storage => :rights3, :path_prefix => 'my/custom/path'
      #   end
      #
      # Which would result in URLs like <tt>http(s)://:server/:bucket_name/my/custom/path/:id/:filename.</tt>
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
      #     has_attachment :storage => :rights3, :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #     has_attachment :storage => :rights3, :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
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
      module Rights3Backend
        class RequiredLibraryNotFoundError < StandardError
        end

        def self.included(base) #:nodoc:
          mattr_reader :bucket_name, :s3_config

          begin
            require 'right_aws'
          rescue LoadError
            raise RequiredLibraryNotFoundError.new('RightAws could not be required')
          end

          @@s3_config = ::ApplicationConfig.amazon_s3
          @@s3_connection = RightAws::S3.new(s3_config[:access_key_id], s3_config[:secret_access_key])
          @@s3_generator = RightAws::S3Generator.new(s3_config[:access_key_id], s3_config[:secret_access_key])
          @@bucket_name = s3_config[:bucket_name]

          base.before_update :rename_file
        end

        def self.protocol
          @protocol ||= (s3_config[:protocol] || RightAws::S3Interface::DEFAULT_PROTOCOL) + '://'
        end

        def self.hostname
          @hostname ||= s3_config[:server] || RightAws::S3Interface::DEFAULT_HOST
        end

        def self.port_string
          if @port_string.nil? then
            if s3_config[:port].nil? then
              if s3_config[:protocol].nil? then
                @port_string = ":#{RightAws::S3Interface::DEFAULT_PORT}"
              else
                if s3_config[:protocol] == 'http://' then
                  @port_string = ':80'
                else
                  @port_string = ':443'
                end
              end
            else
              @port_string = ":#{s3_config[:port]}"
            end
          end
          @port_string
        end

        module ClassMethods
          def s3_protocol
            Technoweenie::AttachmentFu::Backends::Rights3Backend.protocol
          end

          def s3_hostname
            Technoweenie::AttachmentFu::Backends::Rights3Backend.hostname
          end

          def s3_port_string
            Technoweenie::AttachmentFu::Backends::Rights3Backend.port_string
          end
        end

        module InstanceMethods
          def attachment_attributes_valid?
            [:size, :content_type].each do |attr_name|
              enum = attachment_options[attr_name]
              # Call to default_error_messages replaced with call to I18n.translate('activerecord.errors.messages')
              # errors.add attr_name, ActiveRecord::Errors.default_error_messages[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
              errors.add attr_name, I18n.translate('activerecord.errors.messages')[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
            end
          end
        end

        # Overwrites the base filename writer in order to store the old filename
        def filename=(value)
          @old_filename = filename unless filename.nil? || @old_filename
          # square brackets cause problems in Firefox, so replace them
          sanitized = (value.gsub '[', '(').gsub ']', ')'
          write_attribute :filename, sanitized
        end

        # The attachment ID used in the full path of a file
        def attachment_path_id
          ((respond_to?(:parent_id) && parent_id) || id).to_s
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
        # the <tt>:server</tt> variable defaults to <tt>RightAws::S3Interface::DEFAULT_HOST</tt> (s3.amazonaws.com) and can be
        # set using the configuration parameter :server.
        #
        # The optional thumbnail argument will output the thumbnail's filename (if any).
        def s3_url(thumbnail = nil)
          File.join(s3_protocol + s3_hostname + s3_port_string, bucket_name, full_filename(thumbnail))
        end
        alias :public_filename :s3_url

        # All private objects are accessible via an authenticated GET request to the S3 servers. You can generate an
        # authenticated url for an object like this:
        #
        #   @photo.authenticated_s3_url
        #
        # By default authenticated urls expire 5 minutes after they were generated.
        #
        # Expiration options can be specified with a number of seconds relative to now
        # with the <tt>:expires_in</tt> option:
        #
        #   # Expiration in five hours from now
        #   @photo.authenticated_s3_url(:expires_in => 5.hours)
        #
        # Finally, the optional thumbnail argument will output the thumbnail's filename (if any):
        #
        #   @photo.authenticated_s3_url('thumbnail', :expires_in => 5.hours, :use_ssl => true)
        def authenticated_s3_url(*args)
          options   = args.extract_options!
          thumbnail = args.shift
          options[:expires_in] ||= 5.minutes
          @@s3_generator.bucket(bucket_name).get(full_filename(thumbnail), options[:expires_in])
        end

        def create_temp_file
          write_to_temp_file current_data
        end

        def current_data
          @@s3_connection.bucket(bucket_name).key(full_filename).data
        end

        def s3_protocol
          Technoweenie::AttachmentFu::Backends::Rights3Backend.protocol
        end

        def s3_hostname
          Technoweenie::AttachmentFu::Backends::Rights3Backend.hostname
        end

        def s3_port_string
          Technoweenie::AttachmentFu::Backends::Rights3Backend.port_string
        end

        protected
          # Called in the after_destroy callback
          def destroy_file
            @@s3_connection.bucket(bucket_name).key(full_filename).delete
          end

          def rename_file
            return unless @old_filename && @old_filename != filename

            old_full_filename = File.join(base_path, @old_filename)

            @@s3_connection.bucket(bucket_name).key(old_full_filename).rename(full_filename)

            @old_filename = nil
            true
          end

          def save_to_storage
            if save_attachment?
              if temp_path then
                temp_data = open(temp_path, 'rb') { |io| io.read }
              end
              @@s3_connection.bucket(bucket_name).put(full_filename, temp_data, {}, attachment_options[:s3_access], {'content-type' => content_type})
            end

            @old_filename = nil
            true
          end
      end
    end
  end
end