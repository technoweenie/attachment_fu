AttachmentFu.create_task :resize do |attachment, options|
  options[:with] ||= :core_image
  AttachmentFu::Pixels.new options[:with], attachment.full_filename do
    data = with_image { |img| resize_image img, options[:to] }
    attachment.width  = data.width  if attachment.respond_to?(:width)
    attachment.height = data.height if attachment.respond_to?(:height)
  end
end