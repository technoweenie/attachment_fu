module AttachmentFu
  class Tasks
    attr_reader :klass
    
    def initialize(klass)
      @klass = klass
    end
  end
end