module AttachmentFu
  module Pixels
    def self.[](key)
      @@key_to_class ||= {}
      @@key_to_class[key] ||= begin
        path = key.to_s
        require "attachment_fu/pixels/#{path}"
        const_get(path.classify)
      end
    end

    # Base class for all Pixel-related tasks
    class Task
      def initialize(klass, options)
        options[:with] ||= :mojo_magick
        extend AttachmentFu::Pixels[options[:with]]
      end
    end

    class Image
      attr_accessor :filename, :width, :height, :size

      def initialize(filename = nil)
        @filename = filename
        yield self if block_given?
        @size     = File.size(filename) if filename && File.exist?(filename)
      end
    end
  end
end