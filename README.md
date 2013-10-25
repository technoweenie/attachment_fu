attachment-fu
=============

attachment_fu is a plugin by Rick Olson (aka technoweenie <http://techno-weenie.net>) and is the successor to acts_as_attachment.  To get a basic run-through of its capabilities, check out Mike Clark's tutorial <http://clarkware.com/cgi/blosxom/2007/02/24#FileUploadFu>.


attachment_fu functionality
===========================

attachment_fu facilitates file uploads in Ruby on Rails.  There are a few storage options for the actual file data, but the plugin always at a minimum stores metadata for each file in the database.

There are four storage options for files uploaded through attachment_fu:
  File system
  Database file
  Amazon S3
  Rackspace (Mosso) Cloud Files

Each method of storage many options associated with it that will be covered in the following section.  Something to note, however, is that the Amazon S3 storage requires you to modify config/amazon_s3.yml, the Rackspace Cloud Files storage requires you to modify config/rackspace_cloudfiles.yml, and the Database file storage requires an extra table.


attachment_fu models
====================

For all three of these storage options a table of metadata is required.  This table will contain information about the file (hence the 'meta') and its location.  This table has no restrictions on naming, unlike the extra table required for database storage, which must have a table name of db_files (and by convention a model of DbFile).
  
In the model there are two methods made available by this plugins: has_attachment and validates_as_attachment.

has_attachment(options = {})
  This method accepts the options in a hash:
    :content_type     # Allowed content types.
                      # Allows all by default.  Use :image to allow all standard image types.
    :min_size         # Minimum size allowed.
                      # 1 byte is the default.
    :max_size         # Maximum size allowed.
                      # 1.megabyte is the default.
    :size             # Range of sizes allowed.
                      # (1..1.megabyte) is the default.  This overrides the :min_size and :max_size options.
    :resize_to        # Used by RMagick to resize images.
                      # Pass either an array of width/height, or a geometry string.
    :thumbnails       # Specifies a set of thumbnails to generate.
                      # This accepts a hash of filename suffixes and RMagick resizing options.
                      # This option need only be included if you want thumbnailing.
    :thumbnail_class  # Set which model class to use for thumbnails.
                      # This current attachment class is used by default.
    :path_prefix      # Path to store the uploaded files in.
                      # Uses public/#{table_name} by default for the filesystem, and just #{table_name} for the S3 and Cloud Files backend.  
                      # Setting this sets the :storage to :file_system.
    :partition        # Whether to partiton files in directories like /0000/0001/image.jpg. Default is true. Only applicable to the :file_system backend.
    :storage          # Specifies the storage system to use..
                      # Defaults to :db_file.  Options are :file_system, :db_file, :s3, :cloud_files, and :mogile_fs.
    :cloudfront       # If using S3 for storage, this option allows for serving the files via Amazon CloudFront.
                      # Defaults to false.
    :store_name       # When using multiple stores per attachment, this specifies a unique name for the store.  Should be a symbol.
    :processor        # Sets the image processor to use for resizing of the attached image.
                      # Options include ImageScience, Rmagick, and MiniMagick.  Default is whatever is installed.
    :uuid_primary_key # If your model's primary key is a 128-bit UUID in hexadecimal format, then set this to true.
    :association_options  # attachment_fu automatically defines associations with thumbnails with has_many and belongs_to. If there are any additional options that you want to pass to these methods, then specify them here.
    

  Examples:
    has_attachment :max_size => 1.kilobyte
    has_attachment :size => 1.megabyte..2.megabytes
    has_attachment :content_type => 'application/pdf'
    has_attachment :content_type => ['application/pdf', 'application/msword', 'text/plain']
    has_attachment :content_type => :image, :resize_to => [50,50]
    has_attachment :content_type => ['application/pdf', :image], :resize_to => 'x50'
    has_attachment :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
    has_attachment :storage => :file_system, :path_prefix => 'public/files'
    has_attachment :storage => :file_system, :path_prefix => 'public/files', 
                   :content_type => :image, :resize_to => [50,50], :partition => false
    has_attachment :storage => :file_system, :path_prefix => 'public/files',
                   :thumbnails => { :thumb => [50, 50], :geometry => 'x50' }
    has_attachment :storage => :s3
    has_attachment :store => :s3, :cloudfront => true
    has_attachment :storage => :cloud_files
    # (multiple data stores )
    has_attachment :store_name => :fs, :storage => :file_system
    has_attachment :store_name => :s3, :storage => :s3

validates_as_attachment
  This method prevents files outside of the valid range (:min_size to :max_size, or the :size range) from being saved.  It does not however, halt the upload of such files.  They will be uploaded into memory regardless of size before validation.
  
  Example:
    validates_as_attachment


attachment_fu migrations
========================

Fields for attachment_fu metadata tables...
  in general:
    size,         :integer  # file size in bytes
    content_type, :string   # mime type, ex: application/mp3
    filename,     :string   # sanitized filename
  that reference multiple attachment stores:
    stores,       :string
  that reference images:
    height,       :integer  # in pixels
    width,        :integer  # in pixels
  that reference images that will be thumbnailed:
    parent_id,    :integer  # id of parent image (on the same table, a self-referencing foreign-key).
                            # Only populated if the current object is a thumbnail.
    thumbnail,    :string   # the 'type' of thumbnail this attachment record describes.  
                            # Only populated if the current object is a thumbnail.
                            # Usage:
                            # [ In Model 'Avatar' ]
                            #   has_attachment :content_type => :image, 
                            #                  :storage => :file_system, 
                            #                  :max_size => 500.kilobytes,
                            #                  :resize_to => '320x200>',
                            #                  :thumbnails => { :small => '10x10>',
                            #                                   :thumb => '100x100>' }
                            # [ Elsewhere ]
                            # @user.avatar.thumbnails.first.thumbnail #=> 'small'
  md5,            :string   # md5 hash for the attachment
  that reference files stored in the database (:db_file):
    db_file_id,   :integer  # id of the file in the database (foreign key)
    
Field for attachment_fu db_files table:
  data, :binary # binary file data, for use in database file storage


attachment_fu views
===================

There are two main views tasks that will be directly affected by attachment_fu: upload forms and displaying uploaded images.

There are two parts of the upload form that differ from typical usage.
  1. Include ':multipart => true' in the html options of the form_for tag.
    Example:
      <% form_for(:attachment_metadata, :url => { :action => "create" }, :html => { :multipart => true }) do |form| %>
      
  2. Use the file_field helper with :uploaded_data as the field name.
    Example:
      <%= form.file_field :uploaded_data %>

Displaying uploaded images is made easy by the public_filename method of the ActiveRecord attachment objects using file system, s3, and Cloud Files storage.

public_filename(thumbnail = nil)
  Returns the public path to the file.  If a thumbnail prefix is specified it will return the public file path to the corresponding thumbnail.
  Examples:
    attachment_obj.public_filename          #=> /attachments/2/file.jpg
    attachment_obj.public_filename(:thumb)  #=> /attachments/2/file_thumb.jpg
    attachment_obj.public_filename(:small)  #=> /attachments/2/file_small.jpg

When serving files from database storage, doing more than simply downloading the file is beyond the scope of this document.


attachment_fu controllers
=========================

There are two considerations to take into account when using attachment_fu in controllers.

The first is when the files have no publicly accessible path and need to be downloaded through an action.

Example:
  def readme
    send_file '/path/to/readme.txt', :type => 'plain/text', :disposition => 'inline'
  end
  
See the possible values for send_file for reference.


The second is when saving the file when submitted from a form.
Example in view:
 <%= form.file_field :attachable, :uploaded_data %>

Example in controller:
  def create
    @attachable_file = AttachmentMetadataModel.new(params[:attachable])
    if @attachable_file.save
      flash[:notice] = 'Attachment was successfully created.'
      redirect_to attachable_url(@attachable_file)     
    else
      render :action => :new
    end
  end

attachement_fu scripting
====================================

You may wish to import a large number of images or attachments. 
The following example shows how to upload a file from a script. 

#!/usr/bin/env ./script/runner

# required to use ActionController::TestUploadedFile 
require 'action_controller'
require 'action_controller/test_process.rb'

path = "./public/images/x.jpg"

# mimetype is a string like "image/jpeg". One way to get the mimetype for a given file on a UNIX system
# mimetype = `file -ib #{path}`.gsub(/\n/,"")

mimetype = "image/jpeg"

# This will "upload" the file at path and create the new model.
@attachable = AttachmentMetadataModel.new(:uploaded_data => ActionController::TestUploadedFile.new(path, mimetype))
@attachable.save

Testing
======

S3 Test
-----

Instructions for running the s3 tests.

1. ensure mysql is installed, and the 'root' user has no password
2. create the database named `attachment_fu_plugin_test`
3. copy amazon_s3.yml.tpl to test/amazon_s3.yml
4. update test/amazon_s3.yml with your bucket name and s3 credentials
5. run the test script `test/backends/remote/s3_test.rb`

You can run all the test, or just `rake test` but most of the tests are disabled unless you setup their dependencies and config files.


CloudFiles tests
------

ensure that your test container is set 'public'



