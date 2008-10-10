module AttachmentFu
  module Pixels
    def self.[](key)
      @@key_to_class ||= {}
      @@key_to_class[key] ||= begin
        path = key.to_s
        send respond_to?(:require_dependency) ? :require_dependency : :require, "attachment_fu/pixels/#{path}"
        const_get(path.classify)
      end
    end

    # Base class for all Pixel-related tasks
    class Task
      def initialize(klass, options)
        @pixel_adapter = options[:with] || klass.attachment_tasks.default_pixel_adapter
      end

      def with_image(adapter, attachment, &block)
        AttachmentFu::Pixels[adapter || @pixel_adapter].with_image(attachment, &block)
      end

      def get_image_size(adapter, image)
        AttachmentFu::Pixels[adapter || @pixel_adapter].get_image_size(image)
      end

      def resize_image(adapter, image, options = {})
        AttachmentFu::Pixels[adapter || @pixel_adapter].resize_image(image, options)
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

send respond_to?(:require_dependency) ? :require_dependency : :require, "attachment_fu/geometry"