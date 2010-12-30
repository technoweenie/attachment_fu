module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      class MogileFSBackend < BackendDelegator
        class ConfigFileNotFoundError < StandardError; end

        attr_reader :mogile_domain_name
        def initialize(obj, opts)
          @domain_name = opts[:mogile_domain_name] || @@mogile_config[:domain_name]
          super(obj, opts)
        end

        def self.included_in_base(base) #:nodoc:
          begin
            require 'mogilefs'
          rescue LoadError
            raise RequiredLibraryNotFoundError.new('mogilefs could not be loaded')
          end
          
          mogile_config = nil
          if base.attachment_options[:mogile_hosts] && base.attachment_options[:mogile_domain_name]
            mogile_config = base.attachment_options.inject({}) do |memo, arr|
              k, v = arr
              memo[k.to_s.gsub(/^mogile_/, '').to_sym] = v if k.to_s =~ /^mogile_/
              memo
            end
          else 
            mogile_config_path = base.attachment_options[:mogile_config_path] || (RAILS_ROOT + '/config/mogilefs.yml')
            mogile_config = YAML.load(ERB.new(File.read(mogile_config_path)).result)[RAILS_ENV].symbolize_keys
          end
         
          @@mogile_config = mogile_config 
          @@mogile = MogileFS::MogileFS.new(:domain => @@mogile_config[:domain_name], :hosts => @@mogile_config[:hosts])
        end

        # called by the ActiveRecord class from filename=
        def notify_rename
          @old_filename = filename unless filename.nil? || @old_filename
        end  
          
        # The attachment ID used in the full path of a file
        def attachment_path_id
          ((respond_to?(:parent_id) && parent_id) || @obj.id).to_s
        end

        # The pseudo hierarchy containing the file relative to the bucket name
        # Example: <tt>:table_name/:id</tt>
        def base_path
          File.join(attachment_options[:path_prefix], attachment_path_id)
        end

        def full_filename(thumbnail = nil)
          File.join(base_path, thumbnail_name_for(thumbnail))
        end

        def current_data
          @@mogile.get_file_data(full_filename)
        end

        # Called in the after_destroy callback
        def destroy_file
          @@mogile.delete(full_filename)
        end

        def rename_file
          return unless @old_filename && @old_filename != filename

          old_full_filename = File.join(base_path, @old_filename)

          begin 
            @@mogile.rename(old_full_filename, full_filename)
          rescue MogileFS::Backend::KeyExistsError
            # this is hacky.  It's at first blush actually a limitation of the mogilefs-client gem,
            # which always tries to create a new key instead of exposing "set" semantics.
            @@mogile.delete(full_filename)
            retry
          end

          @old_filename = nil
          true
        end

        def save_to_storage
          if save_attachment?
            if temp_path
              @@mogile.store_file(full_filename, @@mogile_config[:mogile_storage_class], temp_path)
            else
              @@mogile.store_content(full_filename, @@mogile_config[:mogile_storage_class], temp_data)
            end
          end

          @old_filename = nil
          true
        end
      end
    end
  end
end
