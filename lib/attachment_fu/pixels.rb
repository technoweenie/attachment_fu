module AttachmentFu
  class Pixels
    def self.[](key)
      @@key_to_class ||= {}
      @@key_to_class[key] ||= begin
        path = key.to_s
        require "attachment_fu/pixels/#{path}"
        const_get(path.classify)
      end
    end
    
    attr_accessor :file
    
    def initialize(processor, file = nil, &block)
      @file = file
      extend self.class[processor]
      instance_eval(&block) if block
    end
    
    def self.resize_task
      lambda do |attachment, options|
        # this is going to change
        # PDI a simple configurable order
        #   task :resize, :with => [:core_image, :gd, :image_science, :rmagick]
        #
        options[:with] ||= :mojo_magick
        new options[:with], attachment.full_filename do
          data = with_image { |img| resize_image img, :size => options[:to], :to => options[:destination] }
          unless options[:skip_size]
            attachment.width  = data.width  if attachment.respond_to?(:width)
            attachment.height = data.height if attachment.respond_to?(:height)
          end
        end
      end
    end

    def self.image_size_task
      lambda do |attachment, options|
        options[:with] ||= :mojo_magick
        new options[:with], attachment.full_filename do
          attachment.width, attachment.height = with_image { |img| get_image_size(img) }
        end
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