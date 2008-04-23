class SampleObjectTask
  def initialize(klass, options)
  end
  
  def call(attachment, options)
    attachment.filename = "modified-by-object-#{attachment.filename}"
  end
end

AttachmentFu.create_task :object_sample, SampleObjectTask