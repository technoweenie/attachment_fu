class Attachment < ActiveRecord::Base
  @@saves = 0
  cattr_accessor :saves
  has_attachment :processor => :rmagick
  validates_as_attachment
  after_save do |record|
    self.saves += 1
  end
end

class LowerQualityAttachment < Attachment
  set_table_name 'attachments'
  has_attachment :resize_to => [55,55], :jpeg_quality => 50
end

class SmallAttachment < Attachment
  has_attachment :max_size => 1.kilobyte
end

class BigAttachment < Attachment
  has_attachment :size => 1.megabyte..2.megabytes
end

class PdfAttachment < Attachment
  has_attachment :content_type => 'pdf'
end

class DocAttachment < Attachment
  has_attachment :content_type => %w(pdf doc txt)
end

class ImageAttachment < Attachment
  has_attachment :content_type => :image, :resize_to => [50,50]
end

class ImageOrPdfAttachment < Attachment
  has_attachment :content_type => ['pdf', :image], :resize_to => 'x50'
end

class ImageWithThumbsAttachment < Attachment
  has_attachment :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
  # after_resize do |record, img|
  #   record.aspect_ratio = img.columns.to_f / img.rows.to_f
  # end
end

class ImageWithPerThumbJpegAttachment < Attachment
  has_attachment :resize_to => '500x500!',
    :thumbnails => { :thumb => '50x50!', :large => '300x300!', :avatar => '64x64!' },
    :jpeg_quality => { :thumb => 90, '<5000' => 85, '>=5000' => 75, :large => 0x200 | 75 }
end

class ImageWithPolymorphicThumbsAttachment < Attachment
  belongs_to :imageable, :polymorphic => true
  has_attachment :thumbnails => {
    :thumb      => [50, 50],
    :geometry   => 'x50',
    :products   => { :large_thumb => '169x169!', :zoomed => '500x500>' },
    :editorials => { :fullsize => '150x100>' },
    'User'      => { :avatar => '64x64!' }
  }
>>>>>>> 33222f02ee9657d0ea9e4654b06cea7ed49cb85b
end

class FileAttachment < ActiveRecord::Base
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment
end

class FileAttachmentWithStringId < ActiveRecord::Base
  set_table_name 'file_attachments_with_string_id'
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment

  before_validation :auto_generate_id
  before_save :auto_generate_id
  @@last_id = 0

  private
    def auto_generate_id
      @@last_id += 1
      self.id = "id_#{@@last_id}"
    end
end

class FileAttachmentWithUuid < ActiveRecord::Base
  set_table_name 'file_attachments_with_string_id'
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick, :uuid_primary_key => true
  validates_as_attachment

  before_validation :auto_generate_id
  before_save :auto_generate_id
  @@last_id = 0

  private
    def auto_generate_id
      @@last_id += 1
      self.id = "%0127dx" % @@last_id
    end
end

class ImageFileAttachment < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :content_type => :image, :resize_to => [50,50]
end

class ImageWithThumbsFileAttachment < FileAttachment
  has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
<<<<<<< HEAD
  def after_resize(img)
    self.aspect_ratio = img.columns.to_f / img.rows.to_f
  end
=======
  # after_resize do |record, img|
  #   record.aspect_ratio = img.columns.to_f / img.rows.to_f
  # end
>>>>>>> 33222f02ee9657d0ea9e4654b06cea7ed49cb85b
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

begin
  class ImageScienceAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :image_science, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55
  end

  class ImageScienceLowerQualityAttachment < ActiveRecord::Base
    set_table_name 'image_science_attachments'
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :image_science, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55,
      :jpeg_quality => 75
  end

  class ImageScienceWithPerThumbJpegAttachment < ImageScienceAttachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :image_science,
      :resize_to => '100x100',
      :thumbnails => { :thumb => [50, 50], :editorial => '300x120', :avatar => '64x64!' },
      :jpeg_quality => { :thumb => 90, '<5000' => 80, '>=5000' => 75 }
  end
rescue MissingSourceFile
  puts $!.message
  puts "no ImageScience"
end

begin
  class CoreImageAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :core_image, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55
  end

  class LowerQualityCoreImageAttachment < CoreImageAttachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :core_image, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55,
      :jpeg_quality => 50
  end

  class CoreImageWithPerThumbJpegAttachment < CoreImageAttachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :core_image,
      :resize_to => '100x100',
      :thumbnails => { :thumb => [50, 50], :editorial => '300x120', :avatar => '64x64!' },
      :jpeg_quality => { :thumb => 90, '<5000' => 80, '>=5000' => 75 }
  end
rescue MissingSourceFile
  puts $!.message
  puts "no CoreImage"
end

begin
  class MiniMagickAttachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55
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

  class LowerQualityMiniMagickAttachment < ActiveRecord::Base
    set_table_name 'mini_magick_attachments'
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55,
      :jpeg_quality => 50
  end

  class MiniMagickWithPerThumbJpegAttachment < MiniMagickAttachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :mini_magick,
      :resize_to => '100x100',
      :thumbnails => { :thumb => [50, 50], :editorial => '300x120', :avatar => '64x64!' },
      :jpeg_quality => { :thumb => 90, '<5000' => 80, '>=5000' => 75 }
  end

rescue MissingSourceFile
  puts $!.message
  puts "no Mini Magick"
end

begin
  class GD2Attachment < ActiveRecord::Base
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :gd2, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55
  end

  class LowerQualityGD2Attachment < GD2Attachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :gd2, :thumbnails => { :thumb => [50, 51], :geometry => '31>', :aspect => '25x25!' }, :resize_to => 55,
      :jpeg_quality => 50
  end

  class GD2WithPerThumbJpegAttachment < GD2Attachment
    has_attachment :path_prefix => 'vendor/plugins/attachment_fu/test/files',
      :processor => :gd2,
      :resize_to => '100x100',
      :thumbnails => { :thumb => [50, 50], :editorial => '300x120', :avatar => '64x64!' },
      :jpeg_quality => { :thumb => 90, '<5000' => 80, '>=5000' => 75 }
  end
rescue MissingSourceFile
  puts $!.message
  puts "no GD2"
end


begin
  class S3Attachment < ActiveRecord::Base
    has_attachment :storage => :s3, :processor => :rmagick, :s3_config_path => File.join(File.dirname(__FILE__), '../amazon_s3.yml')
    validates_as_attachment
  end

  class CloudFilesAttachment < ActiveRecord::Base
    has_attachment :storage => :cloud_files, :processor => :rmagick, :cloudfiles_config_path => File.join(File.dirname(__FILE__), '../rackspace_cloudfiles.yml')
    validates_as_attachment
  end

  class S3WithPathPrefixAttachment < S3Attachment
    has_attachment :storage => :s3, :path_prefix => 'some/custom/path/prefix', :processor => :rmagick
    validates_as_attachment
  end

  class CloudFilesWithPathPrefixAttachment < CloudFilesAttachment
    has_attachment :storage => :cloud_files, :path_prefix => 'some/custom/path/prefix', :processor => :rmagick
    validates_as_attachment
  end

rescue
  puts "S3 error: #{$!}"
end
