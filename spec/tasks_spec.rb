require File.dirname(__FILE__) + '/spec_helper'

module AttachmentFu
  describe Tasks do
    describe "processing an attachment" do
      before :all do
        Tasks.all.update \
          :foo => lambda { |a, o| a.filename = "foo-#{o[:a]}-#{a.filename}" },
          :bar => lambda { |a, o| a.filename = "bar-#{o[:a]}-#{a.filename}" }
        @tasks = Tasks.new self do
          task :foo, :a => 1
          task :bar, :a => 2
          task :foo, :a => 3
        end
      end
      
      it "runs them in order" do
        @asset = ProcessableAsset.new 'original'
        @tasks.process @asset
        @asset.filename.should == 'foo-3-bar-2-foo-1-original'
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
  
  class ProcessableAsset
    def self.after_save(*args)    end
    def self.after_destroy(*args) end

    include AttachmentFu

    attr_accessor :filename
    
    def initialize(filename, task_progress = {}, processed_at = nil)
      @filename, @processed_at, @task_progress = filename, processed_at, task_progress
    end
  end
  
  class TrackedAsset < ProcessableAsset
    attr_accessor :task_progress
  end
  
  class TimestampedAsset < TrackedAsset
    attr_accessor :processed_at
  end
end