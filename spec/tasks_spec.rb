require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module AttachmentFu
  describe Tasks do
    before :all do
      Tasks.all.update \
        :foo => FlakyTask,
        :bar => lambda { |a, o| a.filename = "bar-#{o[:a]}-#{a.filename}" },
        :baz => lambda { |a, o| }
      @tasks = Tasks.new self do
        load :baz
        set_pixel_adapter :core_image
        task :bar, :a => 2
        task :foo, :a => 3
        prepend :foo, :a => 1
      end
      @err = Tasks.new self do
        task :foo, :a => 1
        task :bar, :a => 2
        task :foo, :err => true
        task :foo, :a => 3
      end
    end
    
    before do
      [ProcessableAsset, OnlyTimestampedAsset, TrackedAsset, TimestampedAsset].each { |klass| klass.tasks = @tasks }
    end
    
    it "allows tasks to be queued or just loaded" do
      t = Tasks.new self do
        load :foo
        task :bar
        prepend :baz
      end
      
      t[:foo].should be_instance_of(FlakyTask)
      t[:bar].should be_instance_of(Proc)
      t.size.should == 2
      t[0].should == [t[:baz], {}]
      t[1].should == [t[:bar], {}]
    end

    it "knows queued tasks are queued?" do
      @tasks.queued?(:bar).should == true
      @tasks.queued?(:foo).should == true
    end

    it "knows loaded tasks are not queued?" do
      @tasks.queued?(:baz).should == false
    end

    it "allows tasks to be copied" do
      @copied = @tasks.copy_for ProcessableAsset do
        task :bar, :a => 4
      end
      @copied.size.should == 4
      @tasks.size.should  == 3
    end

    it "copies pixel adapter" do
      @copied = @tasks.copy_for(ProcessableAsset)
      @copied.default_pixel_adapter.should == @tasks.default_pixel_adapter
    end

    it "allows copied tasks to be delete specific tasks" do
      @copied = @tasks.copy_for ProcessableAsset do
        delete :foo
        task :bar, :a => 4
      end
      @copied.size.should == 2
      @tasks.size.should  == 3
    end
    
    it "allows copied tasks to clear inherited tasks" do
      @copied = @tasks.copy_for ProcessableAsset do
        clear
        task :bar, :a => 4
      end
      @copied.size.should == 1
      @tasks.size.should  == 3
    end
    
    it "allows processing of single tasks" do
      @asset = ProcessableAsset.new 'original', nil, Time.now.utc
      @asset.should be_processed
      @asset.should_not be_saved
      @asset.process :foo, :a => 5
      @asset.filename.should == 'foo-5-original'
      @asset.should be_saved
    end
    
    it "raises ArgumentError for bad key names" do
      lambda { @tasks[:snarf] }.should raise_error(ArgumentError)
    end
    
    it "raises ArgumentError for bad index" do
      lambda { @tasks[23] }.should raise_error(ArgumentError)
    end
      
    describe "processing an attachment" do
      it "stores the same FlakyTask instance in the stack" do
        @tasks[0].should == [@tasks[:foo], {:a => 1}]
        @tasks[2].should == [@tasks[:foo], {:a => 3}]
      end

      describe "with no task tracking attributes" do
        it "runs them in order" do
          @asset = ProcessableAsset.new 'original'
          @asset.process
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "only processes if its unsaved" do
          @asset = ProcessableAsset.new 'original'
          @asset.should_not be_processed
        end
        
        it "does not run them if the record has been created" do
          @asset = ProcessableAsset.new 'original', nil, Time.now.utc
          @asset.process
          @asset.filename.should == 'original'
        end
        
        it "does not processes if its saved" do
          @asset = ProcessableAsset.new 'original', nil, Time.now.utc
          @asset.should be_processed
        end
        
        it "does not rescue exceptions" do
          @asset = ProcessableAsset.new 'original'
          ProcessableAsset.tasks = @err
          @asset.should_not be_processed
          lambda { @asset.process }.should raise_error(RuntimeError)
        end
      end
      
      describe "with just processed_at attribute" do
        it "runs them in order" do
          @asset = OnlyTimestampedAsset.new 'original'
          @asset.process
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "only processes if its unsaved" do
          @asset = OnlyTimestampedAsset.new 'original'
          @asset.should_not be_processed
        end
        
        it "completes tasks" do
          @asset = OnlyTimestampedAsset.new 'original'
          @asset.process
          @asset.processed_at.should_not be_nil
        end
        
        it "does not run them if the record has been created" do
          @asset = OnlyTimestampedAsset.new 'original', nil, Time.now.utc
          @asset.process
          @asset.filename.should == 'original'
        end
        
        it "does not processes if its saved" do
          @asset = OnlyTimestampedAsset.new 'original', nil, Time.now.utc
          @asset.should be_processed
        end
        
        it "does not rescue exceptions" do
          OnlyTimestampedAsset.tasks = @err
          @asset = OnlyTimestampedAsset.new 'original'
          lambda { @asset.process }.should raise_error(RuntimeError)
        end
      end
      
      describe "with just task_progress hash" do
        it "runs them in order" do
          @asset = TrackedAsset.new 'original'
          @asset.process
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "only processes if its unsaved" do
          @asset = TrackedAsset.new 'original'
          @asset.should_not be_processed
        end
        
        it "completes tasks" do
          @asset = TrackedAsset.new 'original'
          @asset.process
          @asset.task_progress.should == {:complete => true}
        end
        
        it "skips processed tasks" do
          @asset = TrackedAsset.new 'original', {@tasks.stack.first => true}
          @asset.process
          @asset.filename.should == 'foo-3-bar-2-original'
        end
        
        it "does not run them if the record has been created" do
          @asset = TrackedAsset.new 'original', {:complete => true}, Time.now.utc
          @asset.process
          @asset.filename.should == 'original'
        end
        
        it "does not processes if its saved" do
          @asset = TrackedAsset.new 'original', {:complete => true}, Time.now.utc
          @asset.should be_processed
        end
        
        it "rescues exceptions" do
          TrackedAsset.tasks = @err
          @asset = TrackedAsset.new 'original'
          lambda { @asset.process }.should_not raise_error(RuntimeError)
          @asset.task_progress.size.should == 3
          @asset.task_progress[@err[0]].should == true
          @asset.task_progress[@err[1]].should == true
          @asset.task_progress[@err[2]].should be_instance_of(RuntimeError)
        end
      end
      
      describe "with both processed_at and task_progress hash" do
        it "runs them in order" do
          @asset = TimestampedAsset.new 'original'
          @asset.process
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "only processes if its unsaved" do
          @asset = TimestampedAsset.new 'original'
          @asset.should_not be_processed
        end
        
        it "completes tasks" do
          @asset = TimestampedAsset.new 'original'
          @asset.process
          @asset.processed_at.should_not be_nil
          @asset.task_progress.should == {:complete => true}
        end
        
        it "skips processed tasks" do
          @asset = TimestampedAsset.new 'original', {@tasks.stack.first => true}
          @asset.process
          @asset.filename.should == 'foo-3-bar-2-original'
        end
        
        it "does not run them if the record has been created" do
          @asset = TimestampedAsset.new 'original', {@tasks.stack.first => true}, Time.now.utc
          @asset.process
          @asset.filename.should == 'original'
        end
        
        it "does not processes if its saved" do
          @asset = TimestampedAsset.new 'original', {@tasks.stack.first => true}, Time.now.utc
          @asset.should be_processed
        end
        
        it "rescues exceptions" do
          TimestampedAsset.tasks = @err
          @asset = TimestampedAsset.new 'original'
          lambda { @asset.process }.should_not raise_error(RuntimeError)
          @asset.task_progress.size.should == 3
          @asset.task_progress[@err[0]].should == true
          @asset.task_progress[@err[1]].should == true
          @asset.task_progress[@err[2]].should be_instance_of(RuntimeError)
        end
      end
    end

    describe "#create_task" do
      after { Tasks.all.delete :sample }

      it "creates task with proc" do
        AttachmentFu.create_task :sample do |a, o|
        end
        Tasks.all[:sample].should be_instance_of(Proc)
      end
      
      it "creates task with lib path" do
        AttachmentFu.create_task :sample, 'blahblah'
        Tasks.all[:sample].should == 'blahblah'
      end
      
      it "raises ArgumentError if no lib path or proc are given" do
        lambda { AttachmentFu.create_task }.should raise_error(ArgumentError)
      end
    end
    
    describe "with inline proc task" do
      before :all do
        AttachmentFu.create_task :inline do |attachment, options|
          attachment.filename = "inline-#{attachment.filename}"
        end
      end
      
      before do
        @tasks = Tasks.new self do
          task :inline, :foo => :bar
        end
      end
      
      it "retrieves proc task in class Tasks task accessor" do
        Tasks[:inline].should == Tasks.all[:inline]
      end
      
      it "stores proc task reference in Tasks instance accessor" do
        @tasks[:inline].should == Tasks.all[:inline]
      end
      
      it "stores proc task with options as first in the stack" do
        @tasks[0].should == [@tasks[:inline], {:foo => :bar}]
      end
      
      it "processes attachment" do
        @asset = ProcessableAsset.new 'snarf'
        @tasks[:inline].call @asset, nil
        @asset.filename.should == 'inline-snarf'
      end
      
      after :all do
        Tasks.all.delete :inline
      end
    end
    
    describe "with loaded class task" do
      before :all do
        AttachmentFu.create_task :object_sample, "spec/sample_tasks/object_task.rb"
        AttachmentFu.create_task :failed_smaple, "spec/sample_tasks/string_task.rb"
        Tasks.all[:object_sample].should be_instance_of(String)
      end
      
      before do
        @tasks = Tasks.new self do
          task :object_sample, :foo => :bar
        end
      end
      
      it "raises ArgumentError on bad lib task" do
        lambda { Tasks[:failed_smaple] }.should raise_error(ArgumentError)
      end
      
      it "retrieves task class in class task accessor" do
        Tasks[:object_sample].should == SampleObjectTask
      end
      
      it "stores task instance in Tasks instance accessor" do
        @tasks[:object_sample].should be_instance_of(SampleObjectTask)
      end
    end
  end
  
  # simulates task that just might raise an error
  class FlakyTask
    def initialize(whatever, options)
    end
    
    def call(attachment, options)
      if options[:err] then raise "Oh Noes!" end
      attachment.filename = "foo-#{options[:a]}-#{attachment.filename}"
    end
  end
  
  # simulates asset class with no task tracking attributes
  class ProcessableAsset
    class << self
      def before_create(*args) end
      def after_save(*args)    end
      def after_destroy(*args) end
    end

    include AttachmentFu::InstanceMethods

    class << self
      attr_accessor :tasks
      def attachment_tasks() @tasks end
    end

    attr_accessor :filename
    
    def initialize(filename, task_progress = nil, processed_at = nil)
      @new_attachment = processed_at.nil?
      @filename, @processed_at, @task_progress = filename, processed_at, task_progress || {}
    end
    
    def new_record?
      @processed_at.nil?
    end
    
    def saved?
      @saved
    end
    
    def save
      @saved = true
      @processed_at = Time.now.utc
    end
  end
  
  # simulates asset class with only processed_at attribute
  class OnlyTimestampedAsset < ProcessableAsset
    attr_accessor :processed_at
  end
  
  # simulates asset class with only task_progress hash attribute
  class TrackedAsset < ProcessableAsset
    attr_accessor :task_progress
  end
  
  # simulates asset class with both processed_at and task_progress
  class TimestampedAsset < TrackedAsset
    attr_accessor :processed_at
  end
end