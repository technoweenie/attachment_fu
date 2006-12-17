require File.join(File.dirname(__FILE__), 'attachment_fu', 'backends')
require File.join(File.dirname(__FILE__), 'attachment_fu', 'processors')

module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    @@content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png']
    mattr_reader :content_types

    class ThumbnailError < StandardError;  end
    class AttachmentError < StandardError; end

    module ActMethods
      # Options: 
      #   <tt>:content_type</tt> - Allowed content types.  Allows all by default.  Use :image to allow all standard image types.
      #   <tt>:min_size</tt> - Minimum size allowed.  1 byte is the default.
      #   <tt>:max_size</tt> - Maximum size allowed.  1.megabyte is the default.
      #   <tt>:size</tt> - Range of sizes allowed.  (1..1.megabyte) is the default.  This overrides the :min_size and :max_size options.
      #   <tt>:resize_to</tt> - Used by RMagick to resize images.  Pass either an array of width/height, or a geometry string.
      #   <tt>:thumbnails</tt> - Specifies a set of thumbnails to generate.  This accepts a hash of filename suffixes and RMagick resizing options.
      #   <tt>:thumbnail_class</tt> - Set what class to use for thumbnails.  This attachment class is used by default.
      #   <tt>:file_system_path</tt> - path to store the uploaded files.  Uses public/#{table_name} by default.  
      #                                Setting this sets the :storage to :file_system.
      #   <tt>:storage</tt> - Use :file_system to specify the attachment data is stored with the file system.  Defaults to :db_system.
      #
      # Examples:
      #   has_attachment :max_size => 1.kilobyte
      #   has_attachment :size => 1.megabyte..2.megabytes
      #   has_attachment :content_type => 'application/pdf'
      #   has_attachment :content_type => ['application/pdf', 'application/msword', 'text/plain']
      #   has_attachment :content_type => :image, :resize_to => [50,50]
      #   has_attachment :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #   has_attachment :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
      #   has_attachment :storage => :file_system, :file_system_path => 'public/files'
      #   has_attachment :storage => :file_system, :file_system_path => 'public/files', 
      #     :content_type => :image, :resize_to => [50,50]
      #   has_attachment :storage => :file_system, :file_system_path => 'public/files',
      #     :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
      def has_attachment(options = {})
        # this allows you to redefine the acts' options for each subclass, however
        options[:min_size]         ||= 1
        options[:max_size]         ||= 1.megabyte
        options[:size]             ||= (options[:min_size]..options[:max_size])
        options[:thumbnails]       ||= {}
        options[:thumbnail_class]  ||= self

        # only need to define these once on a class
        unless included_modules.include? InstanceMethods
          class_inheritable_accessor :attachment_options
          
          options[:processor]        ||= :rmagick
          options[:storage]          ||= options[:file_system_path] ? :file_system : :db_file
          options[:file_system_path] ||= File.join("public", table_name)
          options[:file_system_path]   = options[:file_system_path][1..-1] if options[:file_system_path].first == '/'

          with_options :foreign_key => 'parent_id' do |m|
            m.has_many   :thumbnails, :dependent => :destroy, :class_name => options[:thumbnail_class].to_s
            m.belongs_to :parent, :class_name => base_class.to_s
          end

          after_destroy :destroy_file
          extend  ClassMethods
          include InstanceMethods
          include Technoweenie::AttachmentFu::const_get("#{options[:storage].to_s.classify}Backend")
          include Technoweenie::AttachmentFu::const_get("#{options[:processor].to_s.classify}Processor")
          before_save :process_attachment
        end
        
        options[:content_type] = [options[:content_type]].flatten.collect { |t| t == :image ? Technoweenie::AttachmentFu.content_types : t }.flatten unless options[:content_type].nil?
        self.attachment_options = options
      end
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

      # Callback after an image has been resized.
      #
      #   class Foo < ActiveRecord::Base
      #     acts_as_attachment
      #     after_resize do |record, img| 
      #       record.aspect_ratio = img.columns.to_f / img.rows.to_f
      #     end
      #   end
      def after_resize(&block)
        write_inheritable_array(:after_resize, [block])
      end

      # Callback after an attachment has been saved either to the file system or the DB.
      # Only called if the file has been changed, not necessarily if the record is updated.
      #
      #   class Foo < ActiveRecord::Base
      #     acts_as_attachment
      #     after_attachment_saved do |record|
      #       ...
      #     end
      #   end
      def after_attachment_saved(&block)
        write_inheritable_array(:after_attachment_saved, [block])
      end

      # Callback before a thumbnail is saved.  Use this to pass any necessary extra attributes that may be required.
      #
      #   class Foo < ActiveRecord::Base
      #     acts_as_attachment
      #     before_thumbnail_saved do |record, thumbnail|
      #       ...
      #     end
      #   end
      def before_thumbnail_saved(&block)
        write_inheritable_array(:before_thumbnail_saved, [block])
      end

      # Get the thumbnail class, which is the current attachment class by default.
      # Configure this with the :thumbnail_class option.
      def thumbnail_class
        attachment_options[:thumbnail_class] = attachment_options[:thumbnail_class].constantize unless attachment_options[:thumbnail_class].is_a?(Class)
        attachment_options[:thumbnail_class]
      end
    end

    module InstanceMethods
      # Checks whether the attachment's content type is an image content type
      def image?
        self.class.image?(content_type)
      end
      
      def thumbnailable?
        image? && respond_to?(:parent_id)
      end

      def thumbnail_class
        self.class.thumbnail_class
      end

      # Gets the thumbnail name for a filename.  'foo.jpg' becomes 'foo_thumbnail.jpg'
      def thumbnail_name_for(thumbnail = nil)
        return filename if thumbnail.blank?
        ext = nil
        basename = filename.gsub /\.\w+$/ do |s|
          ext = s
          ''
        end
        "#{basename}_#{thumbnail}#{ext}"
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
      #   @attachment = Attachment.create! params[:attachment]
      #
      # TODO: Allow it to work with Merb tempfiles too.
      def uploaded_data=(file_data)
        return nil if file_data.nil? || file_data.size == 0 
        self.content_type    = file_data.content_type
        self.filename        = file_data.original_filename if respond_to?(:filename)
        self.attachment_data = file_data.read
      end

      # returns true if the attachment data will be written to the storage system on the next save
      def save_attachment?
        @save_attachment == true
      end

      # Sets the actual binary data.  This is typically called by uploaded_data=, but you can call this
      # manually if you're creating from the console.  This is also where the resizing occurs.
      def attachment_data=(data)
        @attachment_data = nil
        @save_attachment = false
        self.size = 0

        if data
          self.size = data.length
          @save_attachment = true
          @attachment_data = data
        end
      end
      
      # sets a temporary location to the asset.  Use this if the file is already on the local file system
      # and if you do not need to load it into memory.  
      def attachment_file=(file)
        @attachment_file = nil
        @save_attachment = false
        self.size = 0

        if file && File.file?(file)
          file_stat = File.stat(file)
          self.size = file_stat.size
          @save_attachment = true
          @attachment_file = file
        end
      end

      # Retrieve the temporary attachment file data if it exists, or return nil
      def attachment_file_data
        (@attachment_file && File.file?(@attachment_file)) ? File.read(@attachment_file) : nil
      end

      # Sets the content type.
      def content_type=(new_type)
        write_attribute :content_type, new_type.to_s.strip
      end
      
      # sanitizes a filename.
      def filename=(new_name)
        write_attribute :filename, sanitize_filename(new_name)
      end

      # Returns the width/height in a suitable format for the image_tag helper: (100x100)
      def image_size
        [width.to_s, height.to_s] * 'x'
      end

      protected
        @@filename_basename_regex  = /^.*(\\|\/)/
        @@filename_character_regex = /[^\w\.\-]/
        def sanitize_filename(filename)
          returning filename.strip do |name|
            # NOTE: File.basename doesn't work right with Windows paths on Unix
            # get only the filename, not the whole path
            name.gsub! @@filename_basename_regex, ''
            
            # Finally, replace all non alphanumeric, underscore or periods with underscore
            name.gsub! @@filename_character_regex, '_'
          end
        end

        # validates the size and content_type attributes according to the current model's options
        def attachment_attributes_valid?
          [:size, :content_type].each do |attr_name|
            enum = attachment_options[attr_name]
            errors.add attr_name, ActiveRecord::Errors.default_error_messages[:inclusion] unless enum.nil? || enum.include?(send(attr_name))
          end
        end

        # Stub for a #process_attachment method in a processor
        def process_attachment() end

        # Yanked from ActiveRecord::Callbacks, modified so I can pass args to the callbacks besides self.
        # Only accept blocks, however
        def callback_with_args(method, arg = self)
          notify(method)

          result = nil
          callbacks_for(method).each do |callback|
            result = callback.call(self, arg)
            return false if result == false
          end

          return result
        end
    end
  end
end
