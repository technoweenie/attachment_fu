class Attachment < ActiveRecord::Base
  @@saves = 0
  cattr_accessor :saves
  has_attachment :processor => :rmagick
  validates_as_attachment
  after_attachment_saved do |record|
    self.saves += 1
  end
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
  after_resize do |record, img|
    record.aspect_ratio = img.columns.to_f / img.rows.to_f
  end
end

class FileAttachment < ActiveRecord::Base
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment
end

class ImageFileAttachment < FileAttachment
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files',
    :content_type => :image, :resize_to => [50,50]
end

class ImageWithThumbsFileAttachment < FileAttachment
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }, :resize_to => [55,55]
  after_resize do |record, img|
    record.aspect_ratio = img.columns.to_f / img.rows.to_f
  end
end

class ImageWithThumbsClassFileAttachment < FileAttachment
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files',
    :thumbnails => { :thumb => [50, 50] }, :resize_to => [55,55],
    :thumbnail_class => 'ImageThumbnail'
end

class ImageThumbnail < FileAttachment
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files/thumbnails'
end

# no parent
class OrphanAttachment < ActiveRecord::Base
  has_attachment :processor => :rmagick
  validates_as_attachment
end

# no filename, no size, no content_type
class MinimalAttachment < ActiveRecord::Base
  has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files', :processor => :rmagick
  validates_as_attachment
  
  def filename
    "#{id}.file"
  end
end

class ImageScienceAttachment < ActiveRecord::Base
  if Object.const_defined?(:ImageScience)
    has_attachment :file_system_path => 'vendor/plugins/attachment_fu/test/files',
      :processor => :image_science, :thumbnails => { :thumb => [50, 50], :geometry => '53>', :width => 40 }, :resize_to => [55,55]
  end
end
