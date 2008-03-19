module AttachmentFu
  class Pixels
    def self.[](key)
      @@key_to_class ||= {}
      @@key_to_class[key] ||= begin
        const_get(key.to_s.classify)
      end
    end
    
    attr_accessor :file
    
    def initialize(processor, file = nil, &block)
      @file = file
      extend self.class[processor]
      instance_eval(&block) if block
    end

    class Image
      attr_accessor :width, :height, :size, :original
      
      def initialize(original)
        @original = original
        yield self if block_given?
      end
      
      def path
        temp.path
      end
      
      def temp
        @temp ||= begin
          t = Tempfile.new(File.basename(@original))
          t.close
          t
        end
      end
    end
  end
end