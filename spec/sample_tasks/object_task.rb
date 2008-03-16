class SampleObjectTask
  def initialize(klass)
  end
  
  def call(attachment, options)
    attachment.filename = "modified-by-object-#{attachment.filename}"
  end
end

AttachmentFu.create_task :object_sample, SampleObjectTask