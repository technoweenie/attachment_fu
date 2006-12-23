module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module RmagickProcessor
      def self.included(base)
        begin
          require 'RMagick'
        rescue LoadError
          # boo hoo no rmagick
        end
        base.send :extend, ClassMethods
        base.alias_method_chain :process_attachment, :processing
        base.alias_method_chain :after_process_attachment, :processing
      end
      
      module ClassMethods
        # Yields a block containing an RMagick Image for the given binary data.
        def with_image(file, &block)
          begin
            binary_data = file.is_a?(Magick::Image) ? file : Magick::Image.read(file).first unless !Object.const_defined?(:Magick)
          rescue
            # Log the failure to load the image.  This should match ::Magick::ImageMagickError
            # but that would cause acts_as_attachment to require rmagick.
            logger.debug("Exception working with image: #{$!}")
            binary_data = nil
          end
          block.call binary_data if block && binary_data
        ensure
          !binary_data.nil?
        end
      end

      # Allows you to work with an RMagick representation of the attachment in a block.  
      #
      #   @attachment.with_image do |img|
      #     self.data = img.thumbnail(100, 100).to_blob
      #   end
      #
      def with_image(&block)
        self.class.with_image(temp_path, &block)
      end

      # Creates or updates the thumbnail for the current attachment.
      def create_or_update_thumbnail(temp_file, file_name_suffix, *size)
        thumbnailable? || raise(ThumbnailError.new("Can't create a thumbnail if the content type is not an image or there is no parent_id column"))
        returning find_or_initialize_thumbnail(file_name_suffix) do |thumb|
          thumb.attributes = {
            :content_type             => content_type, 
            :filename                 => thumbnail_name_for(file_name_suffix), 
            :temp_path                => temp_file,
            :thumbnail_resize_options => size
          }
          callback_with_args :before_thumbnail_saved, thumb
          thumb.save!
        end
      end

      protected
        def process_attachment_with_processing
          return unless process_attachment_without_processing
          with_image do |img|
            if !respond_to?(:parent_id) || parent_id.nil? # parent image
              thumbnail_for_image(img, attachment_options[:resize_to]) if attachment_options[:resize_to]
            else # thumbnail
              thumbnail_for_image(img, thumbnail_resize_options) if thumbnail_resize_options
            end
            self.width  = img.columns if respond_to?(:width)
            self.height = img.rows    if respond_to?(:height)
            callback_with_args :after_resize, img
          end if image?
        end

        def after_process_attachment_with_processing
          return unless @saved_attachment
          if thumbnailable? && !attachment_options[:thumbnails].blank? && parent_id.nil?
            temp_file = temp_path || create_temp_file
            attachment_options[:thumbnails].each { |suffix, size| create_or_update_thumbnail(temp_file, suffix, *size) }
          end
          after_process_attachment_without_processing
        end

        # Performs the actual resizing operation for a thumbnail
        def thumbnail_for_image(img, size)
          size = size.first if size.is_a?(Array) && size.length == 1 && !size.first.is_a?(Fixnum)
          if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
            size = [size, size] if size.is_a?(Fixnum)
            img.thumbnail!(*size)
          else
            img.change_geometry(size.to_s) { |cols, rows, image| image.resize!(cols, rows) }
          end
          self.temp_path = write_to_temp_file(img.to_blob)
        end

        def find_or_initialize_thumbnail(file_name_suffix)
          respond_to?(:parent_id) ?
            thumbnail_class.find_or_initialize_by_thumbnail_and_parent_id(file_name_suffix.to_s, id) :
            thumbnail_class.find_or_initialize_by_thumbnail(file_name_suffix.to_s)
        end
    end
  end
end