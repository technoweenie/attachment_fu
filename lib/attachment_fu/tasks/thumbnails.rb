module AttachmentFu
  class Tasks
    class Thumbnails
      attr_reader   :options
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
      # 3) pass nil, and subclass the current attachment class
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

        @klass.class_eval do
          # ensure that the get_image_size task is at the top
          attachment_tasks do
            load :resize
            unqueue :get_image_size
            prepend :get_image_size, :with => options[:with]
          end

          # Set the given class as the thumbnail class for the current attachment class
          def self.attachment_thumbnail_class(klass)
            th_task = attachment_tasks[:thumbnails]
            if th_task.thumbnail_class ; raise ArgumentError, "#{name} already has a thumbnail class: #{th_task.thumbnail_class.name}, not #{klass.name}" ; end
            th_task.thumbnail_class = klass

            # create thumbnails association
            unless reflect_on_association(:thumbnails)
              has_many th_task.options[:thumbnails_association], :class_name => "::#{klass.base_class.name}", :foreign_key => th_task.options[:parent_foreign_key], :dependent => :destroy
            end

            # modify a thumbnail class to be used as the thumbnail for this attachment
            klass.class_eval do
              # The attachment ID used in the full path of a file
              def attachment_path_id
                parent_id
              end

              unless reflect_on_association(:parent)
                belongs_to th_task.options[:parent_association], :class_name => "::#{klass.base_class.name}", :foreign_key => th_task.options[:parent_foreign_key]
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
            klass
          end

          def self.inherited(klass)
            attachment_thumbnail_class(klass)
            super
          end
        end
        @klass.attachment_thumbnail_class(@options[:thumbnail_class]) if @options.key?(:thumbnail_class)
      end

      # task :thumbnails, :sizes => {:thumb => '50x50', :tiny => [10, 10]}
      #
      def call(attachment, options)
        @thumbnail_class ||= @klass.const_set(:Thumbnail, Class.new(@klass))

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