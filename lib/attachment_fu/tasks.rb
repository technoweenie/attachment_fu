module AttachmentFu
  class Tasks
    def self.all
      @all ||= {}
    end
    
    def self.[](key)
      all[key]
    end
    
    attr_reader :klass
    attr_reader :stack
    attr_reader :all
    
    def initialize(klass, stack = [], all = {}, &block)
      @klass, @stack, @all = klass, stack, all
      instance_eval(&block) if block
    end
    
    def copy(&block)
      self.class.new(@klass, @stack.dup, @all.dup, &block)
    end
    
    def task(key, options = {})
      t = self.class[key]
      @stack << [t, options]
      @all[key] = t
    end
    
    def [](key_or_index)
      case key_or_index
        when Symbol then @all[key_or_index]
        when Fixnum then @stack[key_or_index]
        else raise(ArgumentError, "Invalid Key: #{key_or_index.inspect}")
      end
    end
  end
end