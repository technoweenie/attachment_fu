class AttachmentTest < ActiveRecord::Base
  has_attachment :processor => :rmagick
  validates_as_attachment
end

class SmallAttachment < AttachmentTest
  has_attachment :max_size => 1.kilobyte
end

class BigAttachment < AttachmentTest
  has_attachment :size => 1.megabyte..2.megabytes
end

class PdfAttachment < AttachmentTest
  has_attachment :content_type => 'pdf'
end

class DocAttachment < AttachmentTest
  has_attachment :content_type => %w(pdf doc txt)
end

class ImageAttachment < AttachmentTest
  has_attachment :content_type => :image, :resize_to => [50,50]
end

class ImageOrPdfAttachment < AttachmentTest
  has_attachment :content_type => ['pdf', :image], :resize_to => 'x50'
end

class ImageWithThumbsAttachment < AttachmentTest
  has_attachment :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
end

class FileAttachment < ActiveRecord::Base
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment
end

class ImageFileAttachment < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :content_type => :image, :resize_to => [50,50]
end

class ImageWithThumbsFileAttachment < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
end

class ImageWithThumbsClassFileAttachment < FileAttachment
  # use file_system_path to test backwards compatibility
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50] }, :resize_to => [55,55],
    :thumbnail_class => 'ImageThumbnail'
end

class ImageThumbnail < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files/thumbnails'
end

# no parent
class OrphanAttachment < ActiveRecord::Base
  has_attachment :processor => :rmagick
  validates_as_attachment
end

# no filename, no size, no content_type
class MinimalAttachment < ActiveRecord::Base
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment

  def filename
    "#{id}.file"
  end
end


class MultiStoreAttachment < ActiveRecord::Base
  self.table_name = "multi_store_attachments"
end

class MultiStoreAttachmentTwoDefaults < MultiStoreAttachment
  has_attachment :store_name => :dbfile, :default => true
  has_attachment :store_name => :fs, :default => true, :path_prefix => 'vendor/plugins/attachment_fu/test/files'
end

class MultiStoreAttachmentTwoFilesystems < MultiStoreAttachment
  has_attachment :store_name => :fs1, :default => true, :path_prefix => 'vendor/plugins/attachment_fu/test/files1'
  has_attachment :store_name => :fs2, :default => true, :path_prefix => 'vendor/plugins/attachment_fu/test/files2'
end

class MultiStoreAttachmentNoDefault < MultiStoreAttachment
  has_attachment :store_name => :store1
  has_attachment :store_name => :store2, :path_prefix => 'vendor/plugins/attachment_fu/test/files'
end

class MultiStoreAttachmentWithThumbnails < MultiStoreAttachment
  has_attachment :store_name => :fs1, :default => true, :path_prefix => 'vendor/plugins/attachment_fu/test/files1', :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
  has_attachment :store_name => :fs2, :default => true, :path_prefix => 'vendor/plugins/attachment_fu/test/files2', :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
end

begin
  class ImageScienceAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :image_science, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no ImageScience"
end

begin
  class CoreImageAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :core_image, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no CoreImage"
end

begin
  class MiniMagickAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end

  class MiniMagickAttachmentWithValidation < ActiveRecord::Base
    self.table_name = "mini_magick_attachments"
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :content_type => :image,
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
    validates_as_attachment
  end
rescue MissingSourceFile
  puts $!.message
  puts "no Mini Magick"
end

begin
  class GD2Attachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :gd2, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
rescue MissingSourceFile
  puts $!.message
  puts "no GD2"
end


begin
  class MiniMagickAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>' }, :resize_to => 55
  end
  class ImageThumbnailCrop < MiniMagickAttachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :square => "50x50c", :vertical => "30x60c", :horizontal => "60x30c"}

    # TODO this is a bad duplication, this method is in the MiniMagick Processor
    def self.calculate_offset(image_width,image_height,image_aspect,thumb_width,thumb_height,thumb_aspect)
    # only crop if image is not smaller in both dimensions

      # special cases, image smaller in one dimension then thumbsize
      if image_width < thumb_width
        offset = (image_height / 2) - (thumb_height / 2)
        command = "#{image_width}x#{thumb_height}+0+#{offset}"
      elsif image_height < thumb_height
        offset = (image_width / 2) - (thumb_width / 2)
        command = "#{thumb_width}x#{image_height}+#{offset}+0"

      # normal thumbnail generation
      # calculate height and offset y, width is fixed
      elsif (image_aspect <= thumb_aspect or image_width < thumb_width) and image_height > thumb_height
        height = image_width / thumb_aspect
        offset = (image_height / 2) - (height / 2)
        command = "#{image_width}x#{height}+0+#{offset}"
      # calculate width and offset x, height is fixed
      else
        width = image_height * thumb_aspect
        offset = (image_width / 2) - (width / 2)
        command = "#{width}x#{image_height}+#{offset}+0"
      end
      # crop image
      command
    end
  end

rescue MissingSourceFile
end

begin
  class MogileFSAttachment < ActiveRecord::Base
    has_attachment :storage => :mogile_fs, :processor => :rmagick, :mogile_config_path => File.join(File.dirname(__FILE__), '../mogilefs.yml')
    validates_as_attachment
  end
rescue
  ENV["TEST_MOGILE"] = "false"
  puts "MogileFS error: #{$!}"
end


begin
  class S3Attachment < ActiveRecord::Base
    has_attachment :storage => :s3, :processor => :rmagick, :s3_config_path => File.join(File.dirname(__FILE__), '../amazon_s3.yml')
    validates_as_attachment
  end

  class S3WithPathPrefixAttachment < S3Attachment
    has_attachment :storage => :s3, :path_prefix => 'some/custom/path/prefix', :processor => :rmagick
    validates_as_attachment
  end
rescue
  ENV["TEST_S3"] = "false"
  puts "S3 error: #{$!}"
end

begin
  class CloudFilesAttachment < ActiveRecord::Base
    has_attachment :storage => :cloud_files, :processor => :rmagick, :cloudfiles_config_path => File.join(File.dirname(__FILE__), '../rackspace_cloudfiles.yml')
    validates_as_attachment
  end


  class CloudFilesWithPathPrefixAttachment < CloudFilesAttachment
    has_attachment :storage => :cloud_files, :path_prefix => 'some/custom/path/prefix', :processor => :rmagick, :cloudfiles_config_path => File.join(File.dirname(__FILE__), '../rackspace_cloudfiles.yml')
    validates_as_attachment
  end
rescue
  ENV["TEST_CLOUDFILES"] = "false"
  puts "CloudFiles error: #{$!}"
end

