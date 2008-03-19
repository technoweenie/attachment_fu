require 'attachment_fu/geometry'
require 'red_artisan/core_image/processor'

module AttachmentFu # :nodoc:
  class Pixels
    module CoreImage
      def with_image(&block)
        block.call OSX::CIImage.from(@file)
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
          new_size = [image.extent.size.width, image.extent.size.height] / size.to_s
          processor.resize(new_size[0], new_size[1])
        end
        
        destination = options[:to] || @file
        AttachmentFu::Pixels::Image.new do |img|
          processor.render do |result|
            img.width  = result.extent.size.width 
            img.height = result.extent.size.height
            result.save destination, OSX::NSJPEGFileType
            img.size = File.size(destination)
          end
        end
      end
    end
  end
end

