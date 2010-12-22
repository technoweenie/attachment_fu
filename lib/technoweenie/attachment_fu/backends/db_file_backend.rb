module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # Methods for DB backed attachments
      class DbFileBackend < BackendDelegator
        def self.included_in_base(base)
          Object.const_set(:DbFile, Class.new(ActiveRecord::Base)) unless Object.const_defined?(:DbFile)
          base.belongs_to  :db_file, :class_name => '::DbFile', :foreign_key => 'db_file_id'
        end

        def rename_file ; end

        # Gets the current data from the database
        def current_data
          db_file.data
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
            @obj.class.update_all ['db_file_id = ?', @obj.db_file_id = db_file.id], ['id = ?', @obj.id]
          end
          true
        end
      end
    end
  end
end
