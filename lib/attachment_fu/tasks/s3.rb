module AttachmentFu
  class Tasks
    class S3
      module ModelMethods
        def s3_url(thumbnail = nil)
          s3_task.url_for(self, thumbnail)
        end

        def s3_authenticated_url
          
        end

        def s3_task
          self.class.attachment_tasks[:s3]
        end
      end

      require 'yaml'
      require 'erb'
      require 'aws/s3'
      include AWS::S3

      attr_reader :config

      # Some valid options:
      #
      #   :config => Path to s3 config file
      #
      def initialize(klass, options)
        klass.send :include, ModelMethods
        @config = load_config_from(options)
      end

      # task :s3
      #
      def call(attachment, options)
        config = load_config_from(options)
      end

      def url_for(attachment, thumbnail = nil, options = nil)
        File.join(protocol(options) + hostname(options) + port_string(options), bucket_name(options), attachment.public_path(thumbnail))
      end

      def protocol(options = nil)
        config = options ? load_config_from(options) : @config
        @protocol ||= config[:use_ssl] ? 'https://' : 'http://'
      end

      def hostname(options = nil)
        config = options ? load_config_from(options) : @config
        @hostname ||= config[:server] || AWS::S3::DEFAULT_HOST
      end

      def port_string(options = nil)
        config = options ? load_config_from(options) : @config
        @port_string ||= (config[:port].nil? || config[:port] == (config[:use_ssl] ? 443 : 80)) ? '' : ":#{config[:port]}"
      end

      def bucket_name(options = nil)
        config = options ? load_config_from(options) : @config
        config[:bucket_name]
      end

    protected
      def load_config_from(options)
        options[:config] ||= File.join(Rails.root, "config", "amazon_s3.yml")
        if @config && @config[:path] == options[:config]
          @config
        else
          if config = File.exist?(options[:config]) && YAML.load(ERB.new(File.read(options[:config])).result)[Rails.env]
            config[:path] = options[:config]
            config.symbolize_keys!
          else
            raise
          end
        end
      rescue
        options[:ignore_missing_config] ? nil : raise(ArgumentError, "S3 config path was not valid: #{options[:config].inspect}")
      end
    end
  end
end

AttachmentFu.create_task :s3, AttachmentFu::Tasks::S3