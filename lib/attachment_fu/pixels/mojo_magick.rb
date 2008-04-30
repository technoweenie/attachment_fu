require 'mojo_magick/image_resources'
require 'mojo_magick/mojo_magick'

module AttachmentFu # :nodoc:
  module Pixels
    module MojoMagick
      def with_image(attachment, &block)
        block.call attachment.full_path
      end

      def get_image_size(image)
        size = ::MojoMagick.get_image_size(image)
        [size[:width], size[:height]]
      end

      # Performs the actual resizing operation for a thumbnail.
      # Returns a AttachmentFu::Pixels::Image object.
      #
      # Options:
      #  - :size - REQUIRED: either an integer, an array of two integers for width and height, or an geometry string.
      #  - :to   - Final location of the saved image.  Defaults to the pixel instance's location.
      #
      def resize_image(image, options = {})
        size = options[:size]
        case size
          when Fixnum then size = [size, size]
          when String then size = get_image_size(image) / size
        end
        destination = options[:to] || image
        AttachmentFu::Pixels::Image.new destination do |img|
          ::MojoMagick.resize(image, destination, :width => size[0], :height => size[1])
          img.width, img.height = get_image_size(destination)
        end
      end
    end
  end
end

