module AttachmentFu
  class Tasks
    class S3
      module ModelClassMethods
        def s3_task
          attachment_tasks[:s3]
        end
      end

      module ModelMethods
        # For authenticated URLs, pass one of these options:
        #
        #   :expires_in => Defaults to 5 minutes.
        #   :auth or :authenticated => if true, create an authenticated URL.
        #
        def s3_url(thumbnail = nil, options = {})
          if thumbnail.is_a?(Hash)
            options   = thumbnail
            thumbnail = nil
          end
          s3_task.url_for(self, thumbnail, options)
        end

        # Retrieve the S3 metadata for the stored object.
        #
        #   @attachment = Attachment.find 1
        #   open(@attachment.filename, 'wb') do |f|
        #     f.write @attachment.s3_object.value
        #   end
        #
        def s3_object(thumbnail = nil)
          (@s3_object ||= {})[thumbnail || :default] ||= s3_task.object_for(self, thumbnail)
        end

        # Stream the S3 object data.
        #
        #   @attachment = Attachment.find 1
        #   open(@attachment.filename, 'wb') do |f|
        #     @attachment.s3_stream(thumbnail) do |chunk|
        #       f.write chunk
        #     end
        #   end
        #
        def s3_stream(thumbnail = nil, &block)
          s3_task.stream_for(self, thumbnail, &block)
        end

        # The path used for working with S3.  By default it is the public path without the leading /.
        def s3_path(thumbnail = nil)
          public_path(thumbnail)[1..-1]
        end

        def s3_task
          self.class.attachment_tasks[:s3]
        end
      end

      require 'aws/s3'
      include AWS::S3

      attr_reader :options

      class << self
        attr_reader :connection_options

        #   :access_key_id     => REQUIRED
        #   :secret_access_key => REQUIRED
        #   :access            => defaults to :authenticated_read.  Other valid choices include: :public_read (common), :public_read_write, and :private.
        #   :server            => defaults to Amazon
        #   :use_ssl           => Use SSL, defaults to false
        #   :port              => Set this for custom ports.  80 or 443 is implied, depending on :use_ssl.
        #   :persistent        => Whether the S3 lib should use persistent connections or not.  
        #   :proxy             => http proxy for accessing S3
        def connect(options)
          @connection_options = options.slice(:access_key_id, :secret_access_key, :server, :port, :use_ssl, :persistent, :proxy)
          AWS::S3::Base.establish_connection!(@connection_options)
        end

        def connected?
          !@connection_options.nil?
        end
      end

      # Some valid options:
      #
      #   # model-specific options
      #   :bucket_name       => REQUIRED
      #   :access            => defaults to :authenticated_read.  Other valid choices include: :public_read (common), :public_read_write, and :private.
      #
      #   # global connection options
      #   :access_key_id     => REQUIRED
      #   :secret_access_key => REQUIRED
      #   :server            => defaults to Amazon
      #   :use_ssl           => Use SSL, defaults to false
      #   :port              => Set this for custom ports.  80 or 443 is implied, depending on :use_ssl.
      #   :persistent        => Whether the S3 lib should use persistent connections or not.  
      #   :proxy             => http proxy for accessing S3
      #
      # AWS::S3 only supports one connection (why would you want to connect to multiple S3 hosts anyway?).  You can 
      # also send only the connection options to AttachmentFu::Tasks::S3.connect(...).
      #
      def initialize(klass, options)
        klass.class_eval do
          extend  ModelClassMethods
          include ModelMethods
        end

        @options = options
        @options[:access] ||= :authenticated_read
        self.class.connect(@options) unless self.class.connected?
      end

      # task :s3
      #
      def call(attachment, options = {})
        options = @options.merge(options)
        store(attachment)
      end

      def store(attachment, options = @options)
        S3Object.store \
          attachment.s3_path,
          File.open(attachment.full_path),
          options[:bucket_name],
          :content_type => attachment.content_type,
          :access => options[:access]
      end

      def rename(attachment, old_path, options = @options)
        S3Object.rename old_path, attachment.s3_path, options[:bucket_name], :access => options[:access]
      end

      def delete(attachment, options = @options)
        S3Object.delete attachment.s3_path, options[:bucket_name]
      end

      def object_for(attachment, thumbnail = nil, options = @options)
        S3Object.find(attachment.s3_path(thumbnail), options[:bucket_name])
      end

      def stream_for(attachment, thumbnail = nil, options = @options, &block)
        S3Object.stream(attachment.s3_path(thumbnail), options[:bucket_name], &block)
      end

      # For authenticated URLs, pass one of these options:
      #
      #   :expires_in => Defaults to 5 minutes.
      #   :auth or :authenticated => if true, create an authenticated URL.
      #
      def url_for(attachment, thumbnail = nil, options = nil)
        options = options ? @options.merge(options) : @options
        if options.key?(:expires_in) || options.key?(:auth) || options.key?(:authenticated)
          S3Object.url_for(attachment.s3_path(thumbnail), options[:bucket_name], options.slice(:expires_in, :use_ssl))
        else
          File.join(protocol(options) + hostname(options) + port_string(options), bucket_name(options), attachment.s3_path(thumbnail))
        end
      end

      def protocol(options = @options)
        @protocol ||= options[:use_ssl] ? 'https://' : 'http://'
      end

      def hostname(options = @options)
        @hostname ||= options[:server] || AWS::S3::DEFAULT_HOST
      end

      def port_string(options = @options)
        @port_string ||= (options[:port].nil? || options[:port] == (options[:use_ssl] ? 443 : 80)) ? '' : ":#{options[:port]}"
      end

      def bucket_name(options = @options)
        options[:bucket_name]
      end
    end
  end
end

AttachmentFu.create_task :s3, AttachmentFu::Tasks::S3