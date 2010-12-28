require 'tempfile'
require 'activerecord'

Tempfile.class_eval do
  # overwrite so tempfiles use the extension of the basename.  important for rmagick and image science
  def make_tmpname(basename, n)
    ext = nil
    sprintf("%s%d-%d%s", basename.to_s.gsub(/\.\w+$/) { |s| ext = s; '' }, $$, n, ext)
  end
end

require 'geometry'

require 'technoweenie/attachment_fu'
require 'technoweenie/attachment_fu/backends/backend_delegator'
require 'technoweenie/attachment_fu/backends/db_file_backend'
require 'technoweenie/attachment_fu/backends/file_system_backend'
require 'technoweenie/attachment_fu/backends/s3_backend'
require 'technoweenie/attachment_fu/backends/cloud_file_backend'
require 'technoweenie/attachment_fu/processors/core_image_processor'
require 'technoweenie/attachment_fu/processors/gd2_processor'
require 'technoweenie/attachment_fu/processors/image_science_processor'
require 'technoweenie/attachment_fu/processors/mini_magick_processor'
require 'technoweenie/attachment_fu/processors/rmagick_processor'

ActiveRecord::Base.send(:extend, Technoweenie::AttachmentFu::ActMethods)
Technoweenie::AttachmentFu.tempfile_path = ATTACHMENT_FU_TEMPFILE_PATH if Object.const_defined?(:ATTACHMENT_FU_TEMPFILE_PATH)
FileUtils.mkdir_p Technoweenie::AttachmentFu.tempfile_path
