require 'digest/md5'
require 'active_support'
require 'active_support/core_ext'
require 'active_support/dependencies'
require 'timeout'

module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    @@default_processors = %w(ImageScience Rmagick MiniMagick Gd2 CoreImage)
    if defined?(Rails)
      @@tempfile_path      = File.join(Rails.root.to_s, 'tmp', 'attachment_fu')
    else
      @@tempfile_path      = File.join(RAILS_ROOT, 'tmp', 'attachment_fu')
    end
    @@content_types      = [
      'image/jpeg',
      'image/pjpeg',
      'image/jpg',
      'image/gif',
      'image/png',
      'image/x-png',
      'image/jpg',
      'image/x-ms-bmp',
      'image/bmp',
      'image/x-bmp',
      'image/x-bitmap',
      'image/x-xbitmap',
      'image/x-win-bitmap',
      'image/x-windows-bmp',
      'image/ms-bmp',
      'application/bmp',
      'application/x-bmp',
      'application/x-win-bitmap',
      'application/preview',
      'image/jp_',
      'application/jpg',
      'application/x-jpg',
      'image/pipeg',
      'image/vnd.swiftview-jpeg',
      'image/x-xbitmap',
      'application/png',
      'application/x-png',
      'image/gi_',
      'image/x-citrix-pjpeg'
    ]
    mattr_reader :content_types, :tempfile_path, :default_processors
    mattr_writer :tempfile_path

    class ThumbnailError < StandardError;  end
    class AttachmentError < StandardError; end

    module ActMethods
      # Options:
      # *  <tt>:content_type</tt> - Allowed content types.  Allows all by default.  Use :image to allow all standard image types.
      # *  <tt>:min_size</tt> - Minimum size allowed.  1 byte is the default.
      # *  <tt>:max_size</tt> - Maximum size allowed.  1.megabyte is the default.
      # *  <tt>:size</tt> - Range of sizes allowed.  (1..1.megabyte) is the default.  This overrides the :min_size and :max_size options.
      # *  <tt>:resize_to</tt> - Used by RMagick to resize images.  Pass either an array of width/height, or a geometry string.
      # *  <tt>:thumbnails</tt> - Specifies a set of thumbnails to generate.  This accepts a hash of filename suffixes and RMagick resizing options.
      # *  <tt>:thumbnail_class</tt> - Set what class to use for thumbnails.  This attachment class is used by default.
      # *  <tt>:path_prefix</tt> - path to store the uploaded files.  Uses public/#{table_name} by default for the filesystem, and just #{table_name}
      #      for the S3 backend.  Setting this sets the :storage to :file_system.

      # *  <tt>:storage</tt> - Use :file_system to specify the attachment data is stored with the file system.  Defaults to :db_system.
      # *  <tt>:cloundfront</tt> - Set to true if you are using S3 storage and want to serve the files through CloudFront.  You will need to
      #      set a distribution domain in the amazon_s3.yml config file. Defaults to false
      # *  <tt>:bucket_key</tt> - Use this to specify a different bucket key other than :bucket_name in the amazon_s3.yml file.  This allows you to use
      #      different buckets for different models. An example setting would be :image_bucket and the you would need to define the name of the corresponding
      #      bucket in the amazon_s3.yml file.

      # *  <tt>:keep_profile</tt> By default image EXIF data will be stripped to minimize image size. For small thumbnails this proivides important savings. Picture quality is not affected. Set to false if you want to keep the image profile as is. ImageScience will allways keep EXIF data.
      #
      # Examples:
      #   has_attachment :max_size => 1.kilobyte
      #   has_attachment :size => 1.megabyte..2.megabytes
      #   has_attachment :content_type => 'application/pdf'
      #   has_attachment :content_type => ['application/pdf', 'application/msword', 'text/plain']
      #   has_attachment :content_type => :image, :resize_to => [50,50]
      #   has_attachment :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #   has_attachment :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files'
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files',
      #     :content_type => :image, :resize_to => [50,50]
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files',
      #     :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
      #   has_attachment :storage => :s3
      #   has_attachment :storage_key => 'store',
      #                     :backends => { 's3' => { :storage => :s3, :path_prefix => 'foo', :max_size => 5.kilobyte, :default => true },
      #                                    'local1' => { :storage => :file_system, :path_prefix => 'data/public' } }

      def has_attachment(options = {})
        # this allows you to redefine the acts' options for each subclass, however
        options[:min_size]         ||= 1
        options[:max_size]         ||= 1.megabyte
        options[:size]             ||= (options[:min_size]..options[:max_size])
        options[:thumbnails]       ||= {}
        options[:thumbnail_class]  ||= self
        options[:s3_access]        ||= :private
        options[:cloudfront]       ||= false
        options[:store_name]       ||= :default
        options[:content_type] = [options[:content_type]].flatten.collect! { |t| t == :image ? Technoweenie::AttachmentFu.content_types : t }.flatten unless options[:content_type].nil?

        unless options[:thumbnails].is_a?(Hash)
          raise ArgumentError, ":thumbnails option should be a hash: e.g. :thumbnails => { :foo => '50x50' }"
        end

        extend ClassMethods unless (class << self; included_modules; end).include?(ClassMethods)
        include InstanceMethods unless included_modules.include?(InstanceMethods)

        attr_accessor :thumbnail_resize_options

        parent_options = attachment_options || {}

        self.attachment_options = options
        # doing these shenanigans so that #attachment_options is available to processors and backends


        attachment_options[:storage]     ||= (attachment_options[:file_system_path] || attachment_options[:path_prefix]) ? :file_system : :db_file
        attachment_options[:storage]     ||= parent_options[:storage]
        attachment_options[:path_prefix] ||= attachment_options[:file_system_path]
        if attachment_options[:path_prefix].nil?
          attachment_options[:path_prefix] = case attachment_options[:storage]
            when :s3 then table_name
            when :cloud_files then table_name
            when :mogile_fs then table_name
            else File.join("public", table_name)
          end
        end
        attachment_options[:path_prefix]   = attachment_options[:path_prefix][1..-1] if options[:path_prefix].first == '/'

        association_options = { :foreign_key => 'parent_id' }
        if attachment_options[:association_options]
          association_options.merge!(attachment_options[:association_options])
        end
        with_options(association_options) do |m|
          m.has_many   :thumbnails, :class_name => "::#{attachment_options[:thumbnail_class]}"
          m.belongs_to :parent, :class_name => "::#{base_class}" unless options[:thumbnails].empty?
        end

        self.attachment_backends ||= {}
        storage_klass_name = case options[:storage]
          when :mogile_fs
            "MogileFS"
          else
            options[:storage].to_s.classify
        end

        storage_klass = Technoweenie::AttachmentFu::Backends.const_get("#{storage_klass_name}Backend")

        self.attachment_backends[attachment_options[:store_name]] = {:klass => storage_klass, :options => attachment_options}
        storage_klass.included_in_base(self)

        # support syntax-sugar of "a = Attachment.new ; a.s3.authenticated_s3_url" for accessing store-specific stuff
        self.class_eval "def #{attachment_options[:store_name]}; get_storage_delegator(:#{attachment_options[:store_name]}); end"

        case attachment_options[:processor]
        when :none, nil
          processors = Technoweenie::AttachmentFu.default_processors.dup
          begin
            if processors.any?
              attachment_options[:processor] = processors.first
              processor_mod = Technoweenie::AttachmentFu::Processors.const_get("#{attachment_options[:processor].to_s.classify}Processor")
              include processor_mod unless included_modules.include?(processor_mod)
            end
          rescue Object, Exception
            raise unless load_related_exception?($!)

            processors.shift
            retry
          end
        else
          begin
            processor_mod = Technoweenie::AttachmentFu::Processors.const_get("#{attachment_options[:processor].to_s.classify}Processor")
            include processor_mod unless included_modules.include?(processor_mod)
          rescue Object, Exception
            raise unless load_related_exception?($!)

            puts "Problems loading #{options[:processor]}Processor: #{$!}"
          end
        end unless parent_options[:processor] # Don't let child override processor
      end

      # helper method for has_attachment, for if you want to set up stuff from a yaml file
      def setup_attachment_fu(extra_opts = {}, config_filename = nil)
        config_file ||= RAILS_ROOT + "/config/attachments.yml"
        raise "No attachment_fu configuration found, tried #{config_file}" unless File.exist?(config_file)

        att_opts = YAML.load(ERB.new(File.read(config_file)).result)[Rails.env]
        raise "No attachment_fu configuration found for environment #{Rails.env}" unless att_opts

        arr = att_opts[self.name.tableize] || att_opts[:default]

        raise "No attachment_fu configuration found for table #{self.name.tableize}" unless arr
        arr = [arr] if arr.is_a?(Hash) # both flavors!
        arr.each do |val|
          options = val.symbolize_keys.merge(extra_opts)

          options[:thumbnails] = options[:thumbnails].symbolize_keys if options[:thumbnails]
          [:store_name, :storage].each { |k|
            options[k] = options.delete(k).to_sym if options[k]
          }

          has_attachment options
        end
      end


      def load_related_exception?(e) #:nodoc: implementation specific
        case
        when e.kind_of?(LoadError), e.kind_of?(MissingSourceFile), $!.class.name == "CompilationError"
          # We can't rescue CompilationError directly, as it is part of the RubyInline library.
          # We must instead rescue RuntimeError, and check the class' name.
          true
        else
          false
        end
      end
      private :load_related_exception?
    end


    module ClassMethods
      delegate :content_types, :to => Technoweenie::AttachmentFu

      # Performs common validations for attachment models.
      def validates_as_attachment
        validates_presence_of :size, :content_type, :filename
        validate              :attachment_attributes_valid?
      end

      # Returns true or false if the given content type is recognized as an image.
      def image?(content_type)
        content_types.include?(content_type)
      end

      def self.extended(base)
        base.class_attribute :attachment_options
        base.class_attribute :attachment_backends
        base.before_destroy :destroy_thumbnails
        base.before_update :rename_files
        base.before_validation :set_size_from_temp_path
        base.before_validation :process_attachment, :process_attachment_moves
        base.before_validation :generate_md5, :if => Proc.new {|a| a.respond_to?(:md5) && a.new_record?}
        base.after_save :after_process_attachment
        base.after_destroy :destroy_files
      end

      # Get the thumbnail class, which is the current attachment class by default.
      # Configure this with the :thumbnail_class option.
      def thumbnail_class
        attachment_options[:thumbnail_class] = attachment_options[:thumbnail_class].constantize unless attachment_options[:thumbnail_class].is_a?(Class)
        attachment_options[:thumbnail_class]
      end

      def new_tempfile(file)
        basename, ext = [File.basename(file), File.extname(file)]

        Tempfile.new([basename, ext], Technoweenie::AttachmentFu.tempfile_path)
      end


      # Copies the given file path to a new tempfile, returning the closed tempfile.
      def copy_to_temp_file(file, temp_base_name)
        tmp = new_tempfile(temp_base_name)
        tmp.close
        FileUtils.cp file, tmp.path
        tmp
      end

      # Writes the given data to a new tempfile, returning the closed tempfile.
      def write_to_temp_file(data, temp_base_name)
        tmp = new_tempfile(temp_base_name)
        tmp.binmode
        tmp.write data
        tmp.close
        tmp
      end
    end

    module InstanceMethods
      # Checks whether the attachment's content type is an image content type
      def image?
        self.class.image?(content_type)
      end

      # Returns true/false if an attachment is thumbnailable.  A thumbnailable attachment has an image content type and the parent_id attribute.
      def thumbnailable?
        image? && respond_to?(:parent_id) && parent_id.nil?
      end

      # Returns the class used to create new thumbnails for this attachment.
      def thumbnail_class
        self.class.thumbnail_class
      end

      # Gets the thumbnail name for a filename.  'foo.jpg' becomes 'foo_thumbnail.jpg'
      def thumbnail_name_for(thumbnail = nil)
        return filename if thumbnail.blank?
        ext = nil
        basename = filename.gsub /\.\w+$/ do |s|
          ext = s; ''
        end
        # ImageScience doesn't create gif thumbnails, only pngs
        ext.sub!(/gif$/, 'png') if attachment_options[:processor] == "ImageScience"
        "#{basename}_#{thumbnail}#{ext}"
      end

      # Creates or updates the thumbnail for the current attachment.
      def create_or_update_thumbnail(temp_file, file_name_suffix, *size)
        thumbnailable? || raise(ThumbnailError.new("Can't create a thumbnail if the content type is not an image or there is no parent_id column"))
        thumb = find_or_initialize_thumbnail(file_name_suffix)

        thumb.temp_paths.unshift temp_file
        thumb.send(:'attributes=', {
          :content_type             => content_type,
          :filename                 => thumbnail_name_for(file_name_suffix),
          :thumbnail_resize_options => size
        })
        thumb.stores = stores
        thumb.save!

        thumb
      end

      # Sets the content type.
      def content_type=(new_type)
        write_attribute :content_type, new_type.to_s.strip
      end

      # Sanitizes a filename.
      def filename=(new_name)
        with_each_store(true) do |store|
          store.notify_rename if store.respond_to?(:notify_rename)
        end

        write_attribute :filename, sanitize_filename(new_name) if column_for_attribute(:filename)
      end

      # Returns the width/height in a suitable format for the image_tag helper: (100x100)
      def image_size
        [width.to_s, height.to_s] * 'x'
      end

      # Returns true if the attachment data will be written to the storage system on the next save
      def save_attachment?
        File.file?(temp_path.to_s)
      end

      # nil placeholder in case this field is used in a form.
      def uploaded_data() nil; end

      # This method handles the uploaded file object.  If you set the field name to uploaded_data, you don't need
      # any special code in your controller.
      #
      #   <% form_for :attachment, :html => { :multipart => true } do |f| -%>
      #     <p><%= f.file_field :uploaded_data %></p>
      #     <p><%= submit_tag :Save %>
      #   <% end -%>
      #
      #   @attachment = AttachmentTest.create! params[:attachment]
      #
      # TODO: Allow it to work with Merb tempfiles too.
      def uploaded_data=(file_data)
        if file_data.respond_to?(:content_type)
          return nil if file_data.size == 0
          self.content_type = file_data.content_type
          self.filename     = file_data.original_filename if respond_to?(:filename)
        else
          return nil if file_data.blank? || file_data['size'] == 0
          self.content_type = file_data['content_type']
          self.filename =  file_data['filename']
          file_data = file_data['tempfile']
        end
        if file_data.is_a?(StringIO)
          file_data.rewind
          set_temp_data file_data.read
        else
          self.temp_paths.unshift file_data
        end
      end

      # Gets the latest temp path from the collection of temp paths.  While working with an attachment,
      # multiple Tempfile objects may be created for various processing purposes (resizing, for example).
      # An array of all the tempfile objects is stored so that the Tempfile instance is held on to until
      # it's not needed anymore.  The collection is cleared after saving the attachment.
      def temp_path
        p = temp_paths.first
        p.respond_to?(:path) ? p.path : p
      end

      # Gets an array of the currently used temp paths.  Defaults to a copy of #full_filename.
      def temp_paths
        @temp_paths ||= []
      end

      # Gets the data from the latest temp file.  This will read the file into memory.
      def temp_data
        save_attachment? ? File.read(temp_path) : nil
      end

      # Writes the given data to a Tempfile and adds it to the collection of temp files.
      def set_temp_data(data)
        temp_paths.unshift write_to_temp_file data unless data.nil?
      end

      # Copies the given file to a randomly named Tempfile.
      def copy_to_temp_file(file)
        self.class.copy_to_temp_file file, random_tempfile_filename
      end

      # Writes the given file to a randomly named Tempfile.
      def write_to_temp_file(data)
        self.class.write_to_temp_file data, random_tempfile_filename
      end

      # supports backwards compat -- we pretend that methods are mixed in.  Might screw with someone using respond_to? though.
      ONE_STORE_METHODS = [:full_filename, :current_data, :base_path, :attachment_path_id, :partitioned_path, :cloudfront_url,
                           :authenticated_s3_url, :s3_config, :cloudfiles_config, :container_name, :cloudfiles_url, :cloudfiles_storage_url,  :cloudfiles_authtoken, :s3_url, :bucket_name]

      ONE_STORE_METHODS.each do |method|
        eval("def #{method}(*args) ; on_one_store(:#{method}, nil, *args) ; end")
      end

      def supports_multiple_stores?
        has_attribute?(:stores)
      end

      def to_store_list(input)
        return [] if input.nil?
        input = input.split(",") if input.is_a?(String)
        input.flatten! if input.is_a?(Array)
        input.map(&:to_sym)
      end

      private :to_store_list

      def stores
        if !supports_multiple_stores?
          [self.class.attachment_backends.keys.first]
        else
          stores = read_attribute(:stores) || ''
          to_store_list(stores)
        end
      end

      def old_stores
        if new_record?
          []
        elsif !supports_multiple_stores?
          [self.class.attachment_backends.keys.first]
        else
          to_store_list(stores_was)
        end
      end

      def stored_in?(backend)
        old_stores.include?(backend)
      end

      def stores=(*input)
        if supports_multiple_stores?
          write_attribute(:stores, input.flatten.uniq.map(&:to_s).join(','))
        end
      end

      # Creates a temp file with the current data.
      def create_temp_file
        write_to_temp_file current_data
      end

      # Allows you to work with a processed representation (RMagick, ImageScience, etc) of the attachment in a block.
      #
      #   @attachment.with_image do |img|
      #     self.data = img.thumbnail(100, 100).to_blob
      #   end
      #
      def with_image(&block)
        self.class.with_image(temp_path, &block)
      end

      def save_without_processing
        without_processing { save }
      end

      def save_without_processing!
        without_processing { save! }
      end

      def generate_md5
        self.md5 = md5_from_file(temp_path || create_temp_file) rescue nil
      end

      protected
        # Generates a unique filename for a Tempfile.
        def random_tempfile_filename
          "#{rand Time.now.to_i}#{filename || 'attachment'}"
        end

        def sanitize_filename(filename)
          return unless filename

          name = filename.strip

          # NOTE: File.basename doesn't work right with Windows paths on Unix
          # get only the filename, not the whole path
          name.gsub! /^.*(\\|\/)/, ''

          # Finally, replace all non alphanumeric, underscore or periods with underscore
          name.gsub! /[^A-Za-z0-9\.\-]/, '_'

          name
        end

        # before_validation callback.
        def set_size_from_temp_path
          self.size = File.size(temp_path) if save_attachment?
        end

        # validates the size and content_type attributes according to the current model's options
        def attachment_attributes_valid?
          [:size, :content_type].each do |attr_name|
            enum = attachment_options[attr_name]
            enum_str = case enum
              when Array
                enum.join(",")
              else
                enum.to_s
            end

            msg = Object.const_defined?(:I18n) ?  I18n.translate("activerecord.errors.messages.inclusion_with_attribute", :attribute => I18n.translate("activerecord.attributes.attachments.#{attr_name}")) :
                                                        ActiveRecord::Errors.default_error_messages[:inclusion]
            unless enum.nil? || enum.include?(send(attr_name))
              errors.add attr_name, msg + " (#{enum_str})"
            end
          end
        end

        # Initializes a new thumbnail with the given suffix.
        def find_or_initialize_thumbnail(file_name_suffix)
          respond_to?(:parent_id) ?
            thumbnail_class.find_or_initialize_by_thumbnail_and_parent_id(file_name_suffix.to_s, id) :
            thumbnail_class.find_or_initialize_by_thumbnail(file_name_suffix.to_s)
        end

        def has_attachment_processor?
          self.respond_to?(:_process_attachment, true)
        end

        def without_processing
          begin
            @no_processing = true
            yield
          ensure
            @no_processing = false
          end
        end


        def process_attachment
          @saved_attachment ||= save_attachment?
          if @saved_attachment && has_attachment_processor? && !@no_processing
            self._process_attachment
          end
          true
        end

        # if we're not given a specific storage engine, we'll grab one that the attachment actually has, starting with the default.
        def get_storage_delegator(backend)
          @attachment_fu_delegators ||= {}

          backends = self.class.attachment_backends
          if backend.nil?
            if backends.size == 1
              backend = backends.keys.first
            else
              list = backends.find_all { |a|
                stored_in?(a[0])
              }
              backend = list.map { |k, v| v[:options][:default] ? k : nil }.compact.first
              if !backend
                backend = list[0][0]
              end
            end
          end

          hash = backends[backend]
          @attachment_fu_delegators[backend] ||= hash[:klass].new(self, hash[:options])
          @attachment_fu_delegators[backend]
        end

        def on_one_store(method, backend, *args)
          delegator = nil
          if backend
            delegator = get_storage_delegator(backend)
          else
            with_each_store(true) { |store|
              # using methods.include instead of respond_to? because the delegation has already screwed up respond_to?
              # checking both the string (ruby 1.8) and the symbol (ruby 1.9)
              if store.methods.include?(method.to_s) || store.methods.include?(method.to_sym)
                delegator = store
                break
              end
            }
          end

          raise NoMethodError, "No stores responded to \"#{method}\"" if delegator.nil?
          delegator.send(method, *args)
        end

        def with_each_store(only_active=false)
          self.class.attachment_backends.each do |k, v|
            if !only_active || stored_in?(k)
              yield get_storage_delegator(k)
            end
          end
        end

        def process_attachment_moves
          return true if !supports_multiple_stores?
          if new_record?
            @saved_attachment = true
            self.stores = default_attachment_stores
            raise "Please configure one attachment store as :default" if stores.empty?
            true
          else
            # update -- if we've set uploaded_data =, we don't need to run these checks
            return true if @saved_attachment

            if Set.new(old_stores) != Set.new(stores)
              data = current_data
              set_temp_data(data) if data
              @saved_attachment = true
            end
          end
        end

        def default_attachment_stores
          backends = self.class.attachment_backends
          if backends.size == 1
            [backends.keys.first]
          else
            backends.map { |k, v| v[:options][:default] ? k : nil }.compact
          end
        end

        def logger
          @logger ||= begin
            if Object.const_defined?(:Rails)
              Rails.logger
            else
              Logger.new($stdout)
            end
          end
        end


        # Cleans up after processing.  Thumbnails are created, the attachment is stored to the backend, and the temp_paths are cleared.
        def after_process_attachment
          if @saved_attachment
            set_size_from_temp_path

            if has_attachment_processor? && thumbnailable? && !attachment_options[:thumbnails].blank? && parent_id.nil? && !@no_processing
              temp_file = temp_path || create_temp_file
              attachment_options[:thumbnails].each { |suffix, size| create_or_update_thumbnail(temp_file, suffix, *size) }
            end

            with_each_store do |store|
              name = store.attachment_options[:store_name]

              if stores.include?(name)
                # if we've only got one store, don't bother with fancy-pants logic.  Just raise on failure.
                if stores.size == 1
                  store.save_to_storage
                else
                  begin
                    Timeout.timeout(store.attachment_options[:timeout]) {
                      store.save_to_storage
                    }
                  rescue Exception => e
                    logger.error("Exception saving #{self.filename} to #{name}: #{e.inspect}")
                    new_stores = stores.reject { |s| s == name.to_sym }.join(",")
                    write_attribute(:stores, new_stores)
                    self.class.update_all({:stores => new_stores}, ["id = ?", self.id])
                  end
                end
              elsif stores_was && to_store_list(stores_was).include?(name) && store.current_data # needs a delete
                store.destroy_file
              end
            end

            @temp_paths.clear
            @saved_attachment = nil
            @old_attachment_stores = nil
            @target_attachment_stores = nil
          end
        end

        def destroy_files
          with_each_store(true) do |store|
            store.destroy_file
          end
        end

        def rename_files
          with_each_store(true) do |store|
            store.rename_file
          end
        end

        # Resizes the given processed img object with either the attachment resize options or the thumbnail resize options.
        def resize_image_or_thumbnail!(img)
          if (!respond_to?(:parent_id) || parent_id.nil?) && attachment_options[:resize_to] # parent image
            resize_image(img, attachment_options[:resize_to])
          elsif thumbnail_resize_options # thumbnail
            resize_image(img, thumbnail_resize_options)
          end
        end

        # Removes the thumbnails for the attachment, if it has any
        def destroy_thumbnails
          self.thumbnails.each { |thumbnail| thumbnail.destroy } if thumbnailable?
        end

        def md5_from_file(path)
          digest = Digest::MD5.new
          File.open(path) do |file|
            digest << file.read(4096) until file.eof?
          end
          digest.hexdigest
        end
    end
  end
end
