module AttachmentFu
  class Tasks
    class Thumbnails
      attr_reader   :options, :klass
      attr_accessor :thumbnail_class

      # Some valid options:
      #
      #   :parent_association => :parent
      #   :parent_foreign_key => parent_association.to_s.foreign_key
      #   :thumbnails_association => :thumbnails
      #
      # There are three ways to set the thumbnail class:
      # 1) Let attachment_fu define YourModel::Thumbnail, a straight subclass of your attachment model
      # 2) give the thumbnails task a class name to use:
      #      task :thumbnails, :sizes => {:thumb => '100x100>'}, :thumbnail_class => Foo::Thumbnail
      # 3) give the thumbnails task a class name string to use:
      #      task :thumbnails, :sizes => {:thumb => '100x100>'}, :thumbnail_class => "Foo::Thumbnail"
      #    Attachment_fu will prepare the thumbnail class just before processing the first attachment, so the
      #    Foo::Thumbnail class does not need to exist yet.
      # 4) pass nil, and subclass the current attachment class
      #
      #      class Asset
      #        is_attachment do
      #          task :thumbnails, :sizes => {:thumb => '100x100>'}
      #        end
      #      end
      #
      #      class Thumbnail < Asset
      #      end
      #
      def initialize(klass, options)
        @klass   = klass
        @options = options
        @options[:with]                   ||= klass.attachment_tasks.default_pixel_adapter
        @options[:parent_association]     ||= :parent
        @options[:parent_foreign_key]     ||= @options[:parent_association].to_s.foreign_key
        @options[:thumbnails_association] ||= :thumbnails
        @thumbnail_class_processed          = false

        @klass.class_eval do
          # ensure that the get_image_size task is at the top
          attachment_tasks do
            load :resize
            unqueue :get_image_size
            prepend :get_image_size, :with => options[:with]
          end

          def self.inherited(klass)
            th_task = attachment_tasks[:thumbnails]
            th_task.thumbnail_class ||= klass
            super
            th_task.assign_thumbnail_class_to_attachment_class if !th_task.thumbnail_class_processed?
          end
        end

        if @thumbnail_class = @options[:thumbnail_class]
          assign_thumbnail_class_to_attachment_class
        end
      end

      # task :thumbnails, :sizes => {:thumb => '50x50', :tiny => [10, 10]}
      #
      def call(attachment, options)
        assign_thumbnail_class_to_attachment_class unless @thumbnail_class_processed

        options[:sizes].each do |name, size|
          thumb_name = thumbnail_name_for(attachment, name)
          attachment.process :resize, :with => options[:with], :to => size, :destination => attachment.full_path(thumb_name), :skip_save => true, :skip_size => true
          thumb = @thumbnail_class.new do |thumb|
            thumb.send("#{options[:parent_foreign_key]}=", attachment.id)
            thumb.thumbnail    = name.to_s
            thumb.filename     = thumb_name
            thumb.content_type = attachment.content_type
            thumb.set_temp_path  attachment.full_path(thumb_name)
          end
          thumb.save!
        end
      end

      # Set the given class as the thumbnail class for the current attachment class
      def assign_thumbnail_class_to_attachment_class
        @thumbnail_class ||= @klass.const_set(:Thumbnail, Class.new(@klass))
        if @thumbnail_class.is_a?(String) ; @thumbnail_class = @thumbnail_class.constantize; end
        th_task = self

        # create thumbnails association
        @klass.class_eval do
          unless reflect_on_association(:thumbnails)
            has_many th_task.options[:thumbnails_association], :class_name => "::#{base_class.name}", :foreign_key => th_task.options[:parent_foreign_key], :dependent => :destroy
          end
        end

        # modify a thumbnail class to be used as the thumbnail for this attachment
        @thumbnail_class.class_eval do
          # The attachment ID used in the full path of a file
          def attachment_path_id
            parent_id
          end

          unless reflect_on_association(:parent)
            belongs_to th_task.options[:parent_association], :class_name => "::#{th_task.klass.base_class.name}", :foreign_key => th_task.options[:parent_foreign_key]
          end

          validates_presence_of th_task.options[:parent_foreign_key]

          # ensure that the thumbnails task is not carried over to the thumbnail class,
          # and also ensure that get_image_size is the first task.
          attachment_tasks do
            load :resize
            unqueue :thumbnails, :get_image_size
            prepend :get_image_size, :with => th_task.options[:with]
          end
        end
        @thumbnail_class_processed = true
      end

      def thumbnail_class_processed?
        @thumbnail_class_processed
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