module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    # Methods for file system backed attachments
    module FileSystemBackend
      def self.included(base) #:nodoc:
        base.before_update :rename_file
        base.after_save    :save_to_storage # so the id can be part of the url
      end

      # Gets the attachment data
      def attachment_data
        return @attachment_data if @attachment_data
        
        filename = full_filename
        File.open(filename, 'rb') do |file|
          @attachment_data = file.read
        end if File.file?(filename)
        @attachment_data
      end

      # Gets the full path to the filename in this format:
      #
      #   # This assumes a model name like MyModel
      #   # public/#{table_name} is the default filesystem path 
      #   RAILS_ROOT/public/my_models/5/blah.jpg
      #
      # Overwrite this method in your model to customize the filename.
      # The optional thumbnail argument will output the thumbnail's filename.
      def full_filename(thumbnail = nil)
        file_system_path = (thumbnail ? thumbnail_class : self).attachment_options[:file_system_path].to_s
        File.join(RAILS_ROOT, file_system_path, attachment_path_id, thumbnail_name_for(thumbnail))
      end

      # Used as the base path that #public_filename strips off full_filename to create the public path
      def base_path
        @base_path ||= File.join(RAILS_ROOT, 'public')
      end

      # The attachment ID used in the full path of a file
      def attachment_path_id
        ((respond_to?(:parent_id) && parent_id) || id).to_s
      end

      # Gets the public path to the file
      # The optional thumbnail argument will output the thumbnail's filename.
      def public_filename(thumbnail = nil)
        full_filename(thumbnail).gsub %r(^#{Regexp.escape(base_path)}), ''
      end

      def filename=(value)
        @old_filename = full_filename unless filename.nil? || @old_filename
        write_attribute :filename, sanitize_filename(value)
      end

      # Destroys the file.  Called in the after_destroy callback
      def destroy_file
        FileUtils.rm full_filename rescue nil
      end
      
      def rename_file
        return unless @old_filename && @old_filename != full_filename
        if @save_attachment && File.exists?(@old_filename)
          FileUtils.rm @old_filename
        elsif File.exists?(@old_filename)
          FileUtils.mv @old_filename, full_filename
        end
        @old_filename =  nil
        true
      end
      
      # Saves the file to the file system
      def save_to_storage
        if @save_attachment
          # TODO: This overwrites the file if it exists, maybe have an allow_overwrite option?
          FileUtils.mkdir_p(File.dirname(full_filename))
          
          # TODO Convert to streaming storage to prevent excessive memory usage
          # FileUtils.copy_stream is very efficient in regards to copies
          # OR - get the tmp filename for large files and do FileUtils.cp ? *agile*
          File.open(full_filename, "wb") do |file|
            file.write(attachment_data)
          end
        end
        @old_filename = nil
        true
      end
    end

    # Methods for DB backed attachments
    module DbFileBackend
      def self.included(base) #:nodoc:
        base.belongs_to  :db_file, :class_name => '::DbFile', :foreign_key => 'db_file_id'
        base.before_save :save_to_storage # so the db_file_id can be set
      end

      # Gets the attachment data
      def attachment_data
        @attachment_data ||= db_file.data
      end

      # Destroys the file.  Called in the after_destroy callback
      def destroy_file
        db_file.destroy if db_file
      end
      
      # Saves the data to the DbFile model
      def save_to_storage
        if @save_attachment
          (db_file || build_db_file).data = attachment_data
          db_file.save!
          self.db_file_id = db_file.id # needed for my own sanity, k thx
        end
        true
      end
    end
  end
end