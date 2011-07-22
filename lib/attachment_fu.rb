require 'tempfile'
require 'active_record'

require 'geometry'

require 'technoweenie/attachment_fu'

ActiveSupport::Dependencies.autoload_paths << File.dirname(__FILE__)

ActiveRecord::Base.send(:extend, Technoweenie::AttachmentFu::ActMethods)
Technoweenie::AttachmentFu.tempfile_path = ATTACHMENT_FU_TEMPFILE_PATH if Object.const_defined?(:ATTACHMENT_FU_TEMPFILE_PATH)
FileUtils.mkdir_p Technoweenie::AttachmentFu.tempfile_path
