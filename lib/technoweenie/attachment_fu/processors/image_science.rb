require 'image_science'
module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Processors
      module ImageScience
        def self.included(base)
          base.send :extend, ClassMethods
          base.alias_method_chain :process_attachment, :processing
        end

        module ClassMethods
          # Yields a block containing an RMagick Image for the given binary data.
          def with_image(file, &block)
            ::ImageScience.with_image file, &block
          end
        end

        protected
          def process_attachment_with_processing
            return unless process_attachment_without_processing || !image?
            with_image { |img| resize_image_or_thumbnail! img }
            with_image do |img|
              self.width  = img.width  if respond_to?(:width)
              self.height = img.height if respond_to?(:height)
              callback_with_args :after_resize, img
            end
          end

          # Performs the actual resizing operation for a thumbnail
          def resize_image(img, size)
            self.temp_path = write_to_temp_file('foo')
            img.thumbnail(temp_path, (size.is_a?(Array) ? size.first : size).to_i)
          end
      end
    end
  end
end