Dependencies.load_once_paths << File.expand_path(File.join(lib_path, '..', 'vendor'))

config.after_initialize do
  AttachmentFu.setup ActiveRecord::Base
  AttachmentFu.reset
end

config.to_prepare do
  AttachmentFu.setup ActiveRecord::Base
  AttachmentFu.reset
end

class ActionController::TestUploadedFile
  def respond_to?(*args)
    super || @tempfile.respond_to?(*args)
  end
end
