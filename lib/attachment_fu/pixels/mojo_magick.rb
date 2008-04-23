require 'mojo_magick/image_resources'
require 'mojo_magick/mojo_magick'
require 'attachment_fu/geometry'

module AttachmentFu # :nodoc:
  class Pixels
    module MojoMagick
      def with_image(&block)
        block.call @file
      end

      # Performs the actual resizing operation for a thumbnail.
      # Returns a AttachmentFu::Pixels::Image object.
      #
      # Options:
      #  - :size - REQUIRED: either an integer, an array of two integers for width and height, or an geometry string.
      #  - :to   - Final location of the saved image.  Defaults to the pixel instance's location.
      #
      def resize_image(image, options = {})
        dimensions = ::MojoMagick.get_image_size(image)
        size = options[:size]
        case size
          when Fixnum then size = [size, size]
          when String then size = [dimensions[:width], dimensions[:height]] / size
        end
        destination = options[:to] || image
        AttachmentFu::Pixels::Image.new destination do |img|
          ::MojoMagick.resize(image, destination, :width => size[0], :height => size[1])
          new_dimensions = ::MojoMagick.get_image_size(destination)
          img.width      = new_dimensions[:width]
          img.height     = new_dimensions[:height]
        end
      end
    end
  end
end

