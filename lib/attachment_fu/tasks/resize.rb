module AttachmentFu
  class Tasks
    class Resize < AttachmentFu::Pixels::Task
      def call(attachment, options)
        data = with_image(attachment) { |img| resize_image img, :size => options[:to], :to => options[:destination] }
        unless options[:skip_size]
          attachment.width  = data.width  if attachment.respond_to?(:width)
          attachment.height = data.height if attachment.respond_to?(:height)
        end
      end
    end

    class ImageSize < AttachmentFu::Pixels::Task
      def call(attachment, options)
        attachment.width, attachment.height = with_image(attachment) { |img| get_image_size(img) }
      end
    end
  end
end

# task :resize, :with => :mojo_magic, :to => '50x50'
#
AttachmentFu.create_task :resize,         AttachmentFu::Tasks::Resize
AttachmentFu.create_task :get_image_size, AttachmentFu::Tasks::ImageSize