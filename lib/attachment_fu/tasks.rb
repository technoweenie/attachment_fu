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
  #     def initialize(klass, options)
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
  # After these tasks are created, you can load them for an attachment model in the #is_attachment block.
  # This block gives you access to all the Tasks instance methods:
  #
  #   # keep in mind these are sample tasks
  #   class Photo < ActiveRecord::Base
  #     is_attachment do
  #       # this task runs during Photo#process
  #       task :thumbnail, :size => '75x75'
  #       # this task is loaded, but not run during #process
  #       load :resize
  #     end
  #   end
  #
  #   # create the photo, call the :thumbnail task
  #   @photo = Photo.create!(:uploaded_data => params[:uploaded_data])
  #
  #   # okay, let's just call :resize
  #   @photo.process(:resize, :size => '50x50)
  
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
          send respond_to?(:require_dependency) ? :require_dependency : :require, value
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

    # Default AttachmentFu::Pixels adapter
    attr_reader :default_pixel_adapter

    # Initializes the task for a single AttachmentFu model.  
    def initialize(klass, stack = [], all = {}, &block)
      @klass, @stack, @all = klass, stack, all
      set_pixel_adapter nil
      instance_eval(&block) if block
    end

    def set_pixel_adapter(value)
      @default_pixel_adapter = value || :mojo_magick
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
    def copy_for(klass, &block)
      copy = self.class.new(klass, @stack.dup, @all.dup, &block)
      copy.set_pixel_adapter(@default_pixel_adapter)
      copy
    end
    
    # Adds a new task to this Tasks instance.  If the
    # retrieved task from the global Tasks.all collection is a class
    # it is instantiated.
    def task(key, options = {})
      @stack << [load(key, options), options]
    end

    # Adds a new task to the top of this Tasks instance.
    def prepend(key, options = {})
      @stack.unshift([load(key, options), options])
    end

    # Loads a new task to this Tasks instance, but does not put it
    # in the stack to be called during processing.
    def load(key, options = {})
      t = @all[key] || self.class[key]
      if t.is_a?(Class) then t = t.new(@klass, options) end
      @all[key] = t
    end

    def key?(key_or_index)
      case key_or_index
        when Symbol then @all.key?(key_or_index)
        when Fixnum then @stack.key?(key_or_index)
      end
    end

    def queued?(key_or_index)
      case key_or_index
        when Fixnum then @stack.key?(key_or_index)
        when Symbol
          queued_task = @all[key_or_index]
          queued_task && @stack.any? { |(task, options)| task == queued_task }
      end
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