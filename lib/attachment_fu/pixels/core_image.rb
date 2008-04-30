require 'red_artisan/core_image/processor'

module AttachmentFu # :nodoc:
  module Pixels
    module CoreImage
      def with_image(attachment, &block)
        block.call OSX::CIImage.from(attachment.full_path)
      end

      def get_image_size(image)
        [image.extent.size.width, image.extent.size.height]
      end

      # Performs the actual resizing operation for a thumbnail.
      # Returns a AttachmentFu::Pixels::Image object.
      #
      # Options:
      #  - :size - REQUIRED: either an integer, an array of two integers for width and height, or an geometry string.
      #  - :to   - Final location of the saved image.  Defaults to the pixel instance's location.
      #
      def resize_image(image, options = {})
        processor = ::RedArtisan::CoreImage::Processor.new(image)
        size = options[:size]
        size = size.first if size.is_a?(Array) && size.length == 1
        if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
          if size.is_a?(Fixnum)
            processor.fit(size)
          else
            processor.resize(size[0], size[1])
          end
        else
          new_size = get_image_size(image) / size.to_s
          processor.resize(new_size[0], new_size[1])
        end
        
        destination = options[:to] || @file
        AttachmentFu::Pixels::Image.new destination do |img|
          processor.render do |result|
            img.width, img.height = get_image_size(result)
            result.save destination, OSX::NSJPEGFileType
          end
        end
      end
    end
  end
end

