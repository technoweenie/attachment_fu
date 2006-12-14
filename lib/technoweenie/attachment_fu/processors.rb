module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module RmagickProcessor
      def self.included(base)
        begin
          require 'RMagick'
        rescue LoadError
          # boo hoo no rmagick
        end
        base.after_save :create_attachment_thumbnails # allows thumbnails with parent_id to be created
        base.send :extend, ClassMethods
      end
      
      module ClassMethods
        # Yields a block containing an RMagick Image for the given binary data.
        def with_image(data, &block)
          begin
            binary_data = data.is_a?(Magick::Image) ? data : Magick::Image::from_blob(data).first unless !Object.const_defined?(:Magick)
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
      def with_image(data = self.attachment_data, &block)
        self.class.with_image(data, &block)
      end

      # Creates or updates the thumbnail for the current attachment.
      def create_or_update_thumbnail(file_name_suffix, *size)
        thumbnailable? || raise(ThumbnailError.new("Can't create a thumbnail if the content type is not an image or there is no parent_id column"))
        returning find_or_initialize_thumbnail(file_name_suffix) do |thumb|
          resized_image = resize_image_to(size)
          return if resized_image.nil?
          thumb.attributes = {
            :content_type    => content_type, 
            :filename        => thumbnail_name_for(file_name_suffix), 
            :attachment_data => resized_image.to_blob
          }
          callback_with_args :before_thumbnail_saved, thumb
          thumb.save!
        end
      end

      # Resizes a thumbnail.
      def resize_image_to(size)
        thumb = nil
        with_image do |img|
          thumb = thumbnail_for_image(img, size)
        end
        thumb
      end

      protected
        def create_attachment_thumbnails
          if thumbnailable? && @save_attachment && !attachment_options[:thumbnails].blank? && parent_id.nil?
            attachment_options[:thumbnails].each { |suffix, size| create_or_update_thumbnail(suffix, size) }
          end
          if @save_attachment
            @save_attachment = nil
            callback :after_attachment_saved
          end
        end

        # Performs the actual resizing operation for a thumbnail
        def thumbnail_for_image(img, size)
          size = size.first if size.is_a?(Array) && size.length == 1 && !size.first.is_a?(Fixnum)
          if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
            size = [size, size] if size.is_a?(Fixnum)
            img.thumbnail(size.first, size[1])
          else
            img.change_geometry(size.to_s) { |cols, rows, image| image.resize(cols, rows) }
          end
        end

        def find_or_initialize_thumbnail(file_name_suffix)
          respond_to?(:parent_id) ?
            thumbnail_class.find_or_initialize_by_thumbnail_and_parent_id(file_name_suffix.to_s, id) :
            thumbnail_class.find_or_initialize_by_thumbnail(file_name_suffix.to_s)
        end

        def process_attachment
          with_image do |img|
            resized_img       = (attachment_options[:resize_to] && (!respond_to?(:parent_id) || parent_id.nil?)) ? 
              thumbnail_for_image(img, attachment_options[:resize_to]) : img
            self.width           = resized_img.columns if respond_to?(:width)
            self.height          = resized_img.rows    if respond_to?(:height)
            self.attachment_data = resized_img.to_blob
            callback_with_args :after_resize, resized_img
          end if image?
        end
    end
  end
end