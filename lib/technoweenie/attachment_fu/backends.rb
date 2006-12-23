module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    # Methods for file system backed attachments
    module FileSystemBackend
      def self.included(base) #:nodoc:
        base.before_update :rename_file
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

      def create_temp_file!
        copy_to_temp_file full_filename
      end

      # Destroys the file.  Called in the after_destroy callback
      def destroy_file
        FileUtils.rm full_filename rescue nil
      end
      
      def rename_file
        return unless @old_filename && @old_filename != full_filename
        if save_attachment? && File.exists?(@old_filename)
          FileUtils.rm @old_filename
        elsif File.exists?(@old_filename)
          FileUtils.mv @old_filename, full_filename
        end
        @old_filename =  nil
        true
      end
      
      # Saves the file to the file system
      def save_to_storage
        if save_attachment?
          # TODO: This overwrites the file if it exists, maybe have an allow_overwrite option?
          FileUtils.mkdir_p(File.dirname(full_filename))
          FileUtils.mv @temp_path, full_filename
        end
        @old_filename = nil
        true
      end
      
      def current_data
        File.file?(full_filename) ? File.read(full_filename) : nil
      end
    end

    # Methods for DB backed attachments
    module DbFileBackend
      def self.included(base) #:nodoc:
        Object.const_set(:DbFile, Class.new(ActiveRecord::Base)) unless Object.const_defined?(:DbFile)
        base.belongs_to  :db_file, :class_name => '::DbFile', :foreign_key => 'db_file_id'
        base.before_save :save_to_storage # so the db_file_id can be set
      end

      def create_temp_file!
        write_to_temp_file db_file.data
      end

      # Destroys the file.  Called in the after_destroy callback
      def destroy_file
        db_file.destroy if db_file
      end
      
      # Saves the data to the DbFile model
      def save_to_storage
        if save_attachment?
          (db_file || build_db_file).data = temp_data
          db_file.save!
          self.class.update_all ['db_file_id = ?', self.db_file_id = db_file.id], ['id = ?', id]
        end
        true
      end
      
      def current_data
        db_file.data
      end
    end
  end
end