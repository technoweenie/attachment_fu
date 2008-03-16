require File.dirname(__FILE__) + '/spec_helper'

module AttachmentFu
  describe Tasks do
    before :all do
      Tasks.all.update \
        :foo => FlakyTask,
        :bar => lambda { |a, o| a.filename = "bar-#{o[:a]}-#{a.filename}" }
      @tasks = Tasks.new self do
        task :foo, :a => 1
        task :bar, :a => 2
        task :foo, :a => 3
      end
    end
    
    it "allows tasks to be copied" do
      @copied = @tasks.copy do
        task :bar, :a => 4
      end
      @copied.size.should == 4
      @tasks.size.should  == 3
    end
    
    it "allows copied tasks to be delete specific tasks" do
      @copied = @tasks.copy do
        delete :foo
        task :bar, :a => 4
      end
      @copied.size.should == 2
      @tasks.size.should  == 3
    end
    
    it "allows copied tasks to clear inherited tasks" do
      @copied = @tasks.copy do
        clear
        task :bar, :a => 4
      end
      @copied.size.should == 1
      @tasks.size.should  == 3
    end
      
    describe "processing an attachment" do
      it "stores the same FlakyTask instance in the stack" do
        @tasks[0].should == [@tasks[:foo], {:a => 1}]
        @tasks[2].should == [@tasks[:foo], {:a => 3}]
      end

      describe "with no task tracking attributes" do
        it "runs them in order" do
          @asset = ProcessableAsset.new 'original'
          @tasks.process @asset
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "does not run them if the record has been created" do
          @asset = ProcessableAsset.new 'original', nil, Time.now.utc
          @tasks.process @asset
          @asset.filename.should == 'original'
        end
      end
      
      describe "with just processed_at attribute" do
        it "runs them in order" do
          @asset = OnlyTimestampedAsset.new 'original'
          @tasks.process @asset
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "does not run them if the record has been created" do
          @asset = OnlyTimestampedAsset.new 'original', nil, Time.now.utc
          @tasks.process @asset
          @asset.filename.should == 'original'
        end
      end
      
      describe "with just task_progress hash" do
        it "runs them in order" do
          @asset = TrackedAsset.new 'original'
          @tasks.process @asset
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "skips processed tasks" do
          @asset = TrackedAsset.new 'original', {@tasks.stack.first => true}
          @tasks.process @asset
          @asset.filename.should == 'foo-3-bar-2-original'
        end
        
        it "does not run them if the record has been created" do
          @asset = TrackedAsset.new 'original', true, Time.now.utc
          @tasks.process @asset
          @asset.filename.should == 'original'
        end
      end
      
      describe "with both processed_at and task_progress hash" do
        it "runs them in order" do
          @asset = TimestampedAsset.new 'original'
          @tasks.process @asset
          @asset.filename.should == 'foo-3-bar-2-foo-1-original'
        end
        
        it "skips processed tasks" do
          @asset = TimestampedAsset.new 'original', {@tasks.stack.first => true}
          @tasks.process @asset
          @asset.filename.should == 'foo-3-bar-2-original'
        end
        
        it "does not run them if the record has been created" do
          @asset = TimestampedAsset.new 'original', {@tasks.stack.first => true}, Time.now.utc
          @tasks.process @asset
          @asset.filename.should == 'original'
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
    def initialize(whatever)
    end
    
    def call(attachment, options)
      if options[:err] then raise "Oh Noes!" end
      attachment.filename = "foo-#{options[:a]}-#{attachment.filename}"
    end
  end
  
  # simulates asset class with no task tracking attributes
  class ProcessableAsset
    def self.before_create(*args) end
    def self.after_save(*args)    end
    def self.after_destroy(*args) end

    include AttachmentFu

    attr_accessor :filename
    
    def initialize(filename, task_progress = nil, processed_at = nil)
      @new_attachment = processed_at.nil?
      @filename, @processed_at, @task_progress = filename, processed_at, task_progress || {}
    end
    
    def new_record?
      @processed_at.nil?
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