module AttachmentFu
  class Tasks
    class Thumbnails
      module ModelMethods
        # The attachment ID used in the full path of a file
        def attachment_path_id
          parent_id
        end
      end

      # Some valid options:
      #
      #   :parent_association => :parent
      #   :parent_foreign_key => parent_association.to_s.foreign_key
      #   :thumbnails_association => :thumbnails
      #
      def initialize(klass, options)
        options[:parent_association]     ||= :parent
        options[:parent_foreign_key]     ||= options[:parent_association].to_s.foreign_key
        options[:thumbnails_association] ||= :thumbnails

        @thumbnail_class = options[:thumbnail_class] || thumbnail_class_for(klass, options)

        @thumbnail_class.class_eval do
          include ModelMethods
          attachment_tasks.clear
          validates_presence_of options[:parent_foreign_key]
          attachment_tasks do
            task :get_image_size, :with => options[:with] unless queued?(:get_image_size)
          end
        end

        klass.attachment_tasks do
          load :resize
          task :get_image_size, :with => options[:with] unless queued?(:get_image_size)
        end

        unless klass.reflect_on_association(:parent)
          klass.belongs_to options[:parent_association], :class_name => "::#{@thumbnail_class.name}", :foreign_key => options[:parent_foreign_key]
        end
        
        unless klass.reflect_on_association(:thumbnails)
          klass.has_many options[:thumbnails_association], :class_name => "::#{@thumbnail_class.name}", :foreign_key => options[:parent_foreign_key]
        end
      end

      # task :thumbnails, :sizes => {:thumb => '50x50', :tiny => [10, 10]}
      #
      def call(attachment, options)
        options[:sizes].each do |name, size|
          thumb_name = thumbnail_name_for(attachment, name)
          attachment.process :resize, :with => options[:with], :to => size, :destination => attachment.full_path(thumb_name), :skip_save => true, :skip_size => true
          thumb = @thumbnail_class.new do |thumb|
            thumb.send("#{options[:parent_foreign_key]}=", attachment.id)
            thumb.thumbnail    = name.to_s
            thumb.filename     = thumb_name
            thumb.content_type = attachment.content_type
            thumb.temp_path    = attachment.full_path(thumb_name)
          end
          thumb.save!
        end
      end

      # Creates a default thumbnail class, which is just a subclass
      # of the attachment with no tasks, and a modified #attachment_path_id 
      # to use #parent_id instead of #id
      def thumbnail_class_for(klass, options)
        klass.const_set(:Thumbnail, Class.new(klass))
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

AttachmentFu.create_task :thumbnails, AttachmentFu::Tasks::Thumbnails