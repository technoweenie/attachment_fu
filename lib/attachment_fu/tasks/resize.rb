require 'attachment_fu/pixels'

# task :resize, :with => :mojo_magic, :to => '50x50'
#
AttachmentFu.create_task :resize, AttachmentFu::Pixels.resize_task
AttachmentFu.create_task :get_image_size, AttachmentFu::Pixels.image_size_task