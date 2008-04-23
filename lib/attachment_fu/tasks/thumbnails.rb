module AttachmentFu
  class Pixels
    class Thumbnails
      def initialize(klass)
        klass.attachment_tasks.load :resize
        puts "#{klass.name} #{klass.object_id} #{klass.attachment_tasks.all.keys}"
        @thumbnail_class = nil
      end

      # task :thumbnails, :sizes => {:thumb => '50x50', :tiny => [10, 10]}
      #
      def call(attachment, options)
        if @thumbnail_class.nil?
          @thumbnail_class = options[:thumbnail_class] || Class.new(attachment.class)
          @thumbnail_class.attachment_tasks.clear
        end
        puts "#{attachment.class.name} #{attachment.class.object_id} #{attachment.class.attachment_tasks.all.keys}"
        options[:sizes].each do |name, size|
          thumb_name = thumbnail_name_for(attachment, name)
          attachment.process :resize, :with => options[:with], :to => size, :destination => attachment.full_path(thumb_name)
          thumb = @thumbnail_class.new do |thumb|
            thumb.thumbnail    = name.to_s
            thumb.filename     = thumb_name
            thumb.content_type = attachment.content_type
            thumb.temp_path    = attachment.full_path(thumb_name)
            puts thumb.inspect
          end
        end
      end

      def thumbnail_name_for(attachment, thumbnail = nil)
        return attachment.filename if thumbnail.blank?
        ext = nil
        basename = attachment.filename.gsub /\.\w+$/ do |s|
          ext = s; ''
        end
        "#{basename}_#{thumbnail}#{ext}"
      end
    end
  end
end

AttachmentFu.create_task :thumbnails, AttachmentFu::Pixels::Thumbnails