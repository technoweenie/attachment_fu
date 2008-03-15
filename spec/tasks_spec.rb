require File.dirname(__FILE__) + '/spec_helper'

module AttachmentFu
  describe Tasks do
    describe "with inline proc task" do
      before :all do
        Tasks.all[:inline] = lambda { |attachment, options| attachment.filename = "inline-#{attachment.filename}" }
      end
      
      before do
        @tasks = Tasks.new self do
          task :inline, :foo => :bar
        end
      end
      
      it "retrieves proc task" do
        Tasks[:inline].should == Tasks.all[:inline]
      end
      
      it "stores proc task reference in instance" do
        @tasks[:inline].should == Tasks.all[:inline]
      end
      
      it "stores proc task with options as first in the stack" do
        @tasks[0].should == [@tasks[:inline], {:foo => :bar}]
      end
      
      after :all do
        Tasks.all.delete :inline
      end
    end
  end
end