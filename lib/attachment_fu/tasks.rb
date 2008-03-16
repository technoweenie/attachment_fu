module AttachmentFu
  # Adds a task to the global Tasks.all collection.  You can call this several ways:
  #
  # This creates a task from a simple Proc:
  #
  #   AttachmentFu.create_task :do_work do |attachment, options|
  #     ...
  #   end
  #
  # This creates a task from a class.  When a task is added to an Attachment model,
  # an instance of the class is created.  The #call method is then used to process.
  #
  #   class SampleObjectTask
  #     def initialize(klass)
  #     end
  #     
  #     def call(attachment, options)
  #       ...
  #     end
  #   end
  #   
  #   AttachmentFu.create_task :do_work, SampleObjectTask
  #
  # You can also create a lazy task with the path to a library to require.  This lets AttachmentFu
  # require the task classes upon their first access.  When that task class is accessed, it should 
  # call #create_task again, passing the loaded class.
  #
  #   AttachmentFu.create_task :do_work, "path/to/sample_object_task" # loads example task from above.
  #
  def self.create_task(key, lib = nil, &block)
    Tasks.all[key] = block || lib || raise(ArgumentError, "Need either a (lib path or class), or a task proc.")
  end

  # Stores a collection of AttachmentFu tasks.
  class Tasks
    # Collection of all globally loaded tasks.  At first, this will usually be a collection of require paths
    # until the tasks are actually used.
    def self.all
      @all ||= {}
    end
    
    # Gets a task by key.  This loads a task's lib if given a path.  This should replace the same 
    # task with a Class for future accesses.
    def self.[](key)
      case value = all[key]
        when String
          require value
          if all[key].is_a?(String) then raise(ArgumentError, "loading #{key.inspect} failed.") end
          all[key]
        else value
      end
    end
    
    # Reference to the AttachmentFu model.
    attr_reader :klass
    
    # Array of tasks to run.  Each 'stack' item is an array containing the task instance and
    # the options hash.  A task is allowed to be run multiple times for a model with different options.
    attr_reader :stack
    
    # Index of task key => task instance.
    attr_reader :all
    
    # Initializes the task for a single AttachmentFu model.  
    def initialize(klass, stack = [], all = {}, &block)
      @klass, @stack, @all = klass, stack, all
      instance_eval(&block) if block
    end
    
    # Deletes all instances of the task this Tasks instance.
    def delete(key)
      if task = @all[key]
        @all.delete(key)
        @stack.delete_if { |s| s.first == task }
      end
    end
    
    # Clears all tasks from this Tasks instance
    def clear
      @stack, @all = [], {}
    end
    
    # Returns the number of tasks to run.
    def size
      @stack.size
    end
    
    def each(&block)
      @stack.each(&block)
    end
    
    def any?(&block)
      @stack.any?(&block)
    end
    
    # Creates a copy of this Tasks instance.
    def copy(&block)
      self.class.new(@klass, @stack.dup, @all.dup, &block)
    end
    
    # Adds a new task to this Tasks instance.  If the
    # retrieved task from the global Tasks.all collection is a class
    # it is instantiated.
    def task(key, options = {})
      t = @all[key] || self.class[key]
      if t.is_a?(Class) then t = t.new(@klass) end
      @stack << [t, options]
      @all[key] = t
    end
    
    # Gets either a task instance by key, or a stack item by index.
    #
    #   @tasks[:foo] # => <#FooTaskInstance>
    #   @tasks[0]    # => [<#FooTaskInstance>, {:foo => :bar}]
    #
    def [](key_or_index)
      case key_or_index
        when Symbol then @all[key_or_index]
        when Fixnum then @stack[key_or_index]
      end || raise(ArgumentError, "Invalid Key: #{key_or_index.inspect}")
    end
  end
end