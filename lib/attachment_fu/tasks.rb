module AttachmentFu
  def self.create_task(key, lib = nil, &block)
    Tasks.all[key] = block || lib || raise(ArgumentError, "Need either a (lib path or class), or a task proc.")
  end

  class Tasks
    def self.all
      @all ||= {}
    end
    
    def self.[](key)
      case value = all[key]
        when String
          require value
          if all[key].is_a?(String) then raise(ArgumentError, "loading #{key.inspect} failed.") end
          all[key]
        else value
      end
    end
    
    attr_reader :klass
    attr_reader :stack
    attr_reader :all
    
    def initialize(klass, stack = [], all = {}, &block)
      @klass, @stack, @all = klass, stack, all
      instance_eval(&block) if block
    end
    
    def delete(key)
      if task = @all[key]
        @stack.delete_if { |s| s.first == task }
      end
    end
    
    def clear
      @stack, @all = [], {}
    end
    
    def size
      @stack.size
    end
    
    def copy(&block)
      self.class.new(@klass, @stack.dup, @all.dup, &block)
    end
    
    def task(key, options = {})
      t = @all[key] || self.class[key]
      if t.is_a?(Class) then t = t.new(@klass) end
      @stack << [t, options]
      @all[key] = t
    end
    
    def [](key_or_index)
      case key_or_index
        when Symbol then @all[key_or_index]
        when Fixnum then @stack[key_or_index]
      end || raise(ArgumentError, "Invalid Key: #{key_or_index.inspect}")
    end
    
    def process(attachment)
      has_progress = attachment.respond_to?(:task_progress)
      @stack.each do |stack_item|
        if attachment.process_task?(stack_item)
          begin
            task, options = stack_item
            task.call attachment, options
            if has_progress then attachment.task_progress[stack_item] = true end
          rescue Object
            if has_progress
              attachment.task_progress[stack_item] = $!
              return
            else
              raise $!
            end
          end
        end
      end
      if has_progress
        attachment.task_progress = {:complete => true}
      end
      attachment.processed_at = Time.now.utc if attachment.respond_to?(:processed_at)
    end
  end
end