$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'vendor')

require 'set'
require 'tempfile'
require 'pathname'

Tempfile.class_eval do
  # overwrite so tempfiles use the extension of the basename.  important for rmagick and image science
  def make_tmpname(basename, n)
    ext = nil
    sprintf("%s%d-%d%s", basename.to_s.gsub(/\.\w+$/) { |s| ext = s; '' }, $$, n, ext)
  end
end

module AttachmentFu
  @@image_content_types = Set.new [
      'image/jpeg',
      'image/pjpeg',
      'image/jpg',
      'image/gif',
      'image/png',
      'image/x-png',
      'image/jpg',
      'image/x-ms-bmp',
      'image/bmp',
      'image/x-bmp',
      'image/x-bitmap',
      'image/x-xbitmap',
      'image/x-win-bitmap',
      'image/x-windows-bmp',
      'image/ms-bmp',
      'application/bmp',
      'application/x-bmp',
      'application/x-win-bitmap',
      'application/preview',
      'image/jp_',
      'application/jpg',
      'application/x-jpg',
      'image/pipeg',
      'image/vnd.swiftview-jpeg',
      'image/x-xbitmap',
      'application/png',
      'application/x-png',
      'image/gi_'
    ]

  def self.image_type?(content_type)
    @@image_content_types.include?(content_type)
  end

  # These methods extend the model base class (usually ActiveRecord::Base).
  module SetupMethods
    # Sets up this class's instances to be treated as attachments.  The options define only the core
    # attachment functions: storing an attachment on the filesystem.  Any external processing 
    # should be done with custom tasks.
    # 
    #   class Attachment < ActiveRecord::Base
    #     is_attachment \
    #       :queued => [true, false] # Sets whether this attachment should be queued or not.  Default: false
    #       :path   => '...'         # Sets the relative path for saved files.  Defaults to public/#{table_name}
    #   end
    #
    # Attachments are saved in partitioned paths created by the ID. A typical path might look like:
    #
    #   RAILS_ROOT/public/photos/0000/0101/shake_and_bake.jpg
    #
    # Tasks are where you can customize AttachmentFu behavior:
    #
    #   class Attachment < ActiveRecord::Base
    #     is_attachment :queued => true do
    #       task :convert_to_flv, :audio => :mp3
    #       task :store_in_s3, :bucket => 'assets.techno-weenie.net'
    #     end
    #
    # See individual tasks for what options they take.  See AttachmentFu::Tasks to see how tasks are processed.
    #
    # The table schema should look like this:
    #
    #   create_table :foo do |t|
    #     t.string  :filename
    #     t.string  :content_type
    #     t.integer :size
    #
    #     # OPTIONAL
    #     t.text :task_progress
    #     t.datetime :processed_at
    #
    #     # PLUS any fields that your tasks may use.
    #   end
    def is_attachment(options = {}, &block)
      setup_attachment_fu_on(self)
      self.queued_attachment = options[:queued]
      self.attachment_path   = options[:path] || attachment_path || File.join("public", table_name)
      self.attachment_tasks(&block)
    end

    def setup_attachment_fu_on(klass)
      class << klass
        attr_writer :attachment_tasks

        def attachment_tasks(&block)
          @attachment_tasks ||= superclass.respond_to?(:attachment_tasks) ? superclass.attachment_tasks.copy_for(self) : AttachmentFu::Tasks.new(self)
          @attachment_tasks.instance_eval(&block) if block
          @attachment_tasks
        end
      end

      klass.class_eval do
        include AttachmentFu::InstanceMethods
        attr_reader :temp_path
        class_inheritable_accessor :queued_attachment
        class_inheritable_accessor :attachment_path
        before_create :set_new_attachment
        after_save    :save_attachment
        after_destroy :delete_attachment
      end
    end
  end

  # joined with #attachment_path to get the full path
  def self.root_path
    @root_path ||= File.expand_path(defined?(RAILS_ROOT) ? RAILS_ROOT : File.dirname(__FILE__))
  end
  
  # Sets the default root_path for all attachment models.
  def self.root_path=(value)
    @root_path = value
  end

  # Sets up a class for attachment_fu.  By default, this sets ActiveRecord up with an #is_attachment method.
  def self.setup(klass)
    klass.extend SetupMethods
  end

  # Sets default tasks
  def self.reset
    Tasks
    [:resize, :thumbnails].each do |task|
      create_task task, "attachment_fu/tasks/#{task}"
    end
    create_task :get_image_size, "attachment_fu/tasks/resize"
  end

  # This mixin is included in attachment classes by AttachmentFu::SetupMethods.is_attachment.
  module InstanceMethods
    # Strips filename of any funny characters.
    def filename=(value)
      strip_filename value if value
      write_attribute :filename, value
    end

    # nil placeholder in case this field is used in a form.
    def uploaded_data() nil; end

    # This method handles the uploaded file object.  If you set the field name to uploaded_data, you don't need
    # any special code in your controller.
    #
    #   <% form_for :attachment, :html => { :multipart => true } do |f| -%>
    #     <p><%= f.file_field :uploaded_data %></p>
    #     <p><%= submit_tag :Save %>
    #   <% end -%>
    #
    #   @attachment = Attachment.create! params[:attachment]
    #
    def uploaded_data=(file_data)
      return nil if file_data.nil? || file_data.size == 0 
      self.content_type = file_data.content_type
      self.filename     = file_data.original_filename
      if file_data.respond_to?(:rewind) # it's an IO object
        file_data.rewind
        tmp = Tempfile.new(filename)
        tmp.binmode
        tmp << file_data.read
        tmp.rewind
        set_temp_path tmp
      else
        set_temp_path file_data
      end
    end

    # The attachment ID used in the full path of a file
    def attachment_path_id
      return nil if new_record?
      id.to_i
    end

    # overrwrite this to do your own app-specific partitioning. 
    # you can thank Jamis Buck for this: http://www.37signals.com/svn/archives2/id_partitioning.php
    def partitioned_path(*args)
      return nil if attachment_path_id.nil?
      ("%08d" % attachment_path_id).scan(/..../) + args
    end

    def public_path(thumbnail = nil)
      File.join(attachment_path, *partitioned_path(thumbnailed_filename(thumbnail))).sub(/^public\//, '/')
    end

    def full_path(thumbnail = nil)
      return nil if attachment_path_id.nil?
      File.expand_path(File.join(AttachmentFu.root_path, attachment_path, *partitioned_path(thumbnailed_filename(thumbnail))))
    end

    # Sets the path to the attachment about to be saved.  Could be a string path to a file, 
    # a Pathname referencing a file, or a Tempfile.
    def set_temp_path(value)
      self.size       = value.is_a?(String) || !value.respond_to?(:size) ? File.size(value) : value.size
      self.filename ||= basename_for value
      @temp_path      = value
    end

    def image?
      AttachmentFu.image_type?(content_type)
    end

    # Overwrite this if you want.  This is called when AttachmentFu processing is delayed for a queue.
    def queue_processing
    end
  
    # Processes an attachment with its current stack of tasks.  Optionally, it stores
    # the process time in #processed_at when finished, or the progress of which tasks 
    # have run in #task_progress.
    #
    # If #processed_at is available, this will set it to a current timestamp when all processing
    # has been complete.
    #
    # If #task_progress is available, it will track the progress of the stack of tasks.  Either
    # a true value or an exception is used as a key.  When all processing is done, the #task_progress
    # hash is set to a static value of {:complete => true}
    #
    # You can also process a loaded task with the given set of options, but #task_progress and #processed_at
    # are ignored.
    #
    #   # process the Photo instance's queued tasks
    #   @photo.process
    #
    #   # process a single task directly
    #   @photo.process(:resize, :size => '75x75')
    #
    def process(task_key = true, options = {})
      if has_progress = respond_to?(:task_progress)
        self.task_progress ||= {}
      end
      case task_key
        when Symbol
          task = self.class.attachment_tasks[task_key]
          process_single_task(task, options, false)
        else
          process_all_tasks(has_progress)
      end
      save unless options[:skip_save]
    end
  
    # Returns true/false if an attachment has been processed.
    def processed?
      return true if respond_to?(:processed_at)  && processed_at
      return true if respond_to?(:task_progress) && task_progress[:complete]
      !self.class.attachment_tasks.any? { |s| process_task?(s) }
    end

  protected
    def thumbnailed_filename(thumbnail)
      if thumbnail
        pieces = filename.split('.')
        pieces[pieces.size > 1 ? -2 : -1] << "_#{thumbnail}"
        pieces * "."
      else
        filename
      end
    end

    def process_all_tasks(has_progress = respond_to?(:task_progress))
      self.class.attachment_tasks.each do |stack_item|
        if process_task?(stack_item)
          task, options = stack_item
          return unless process_single_task(task, options, has_progress)
        end
      end
      if has_progress
        self.task_progress = {:complete => true}
      end
      self.processed_at = Time.now.utc if respond_to?(:processed_at)
    end
  
    def process_single_task(task, options, has_progress = respond_to?(:task_progress))
      task.call self, options
      if has_progress then task_progress[[task, options]] = true end
      true
    rescue Object
      if has_progress
        task_progress[[task, options]] = $!
        return
      else
        raise $!
      end
    end

    # Checks to see if the given 'stack' (see AttachmentFu::Tasks) needs to be
    # run.  
    def process_task?(stack)
      has_progress  = respond_to?(:task_progress)
      if respond_to?(:processed_at)
        return false if processed_at
        !has_progress || !check_task_progress(stack)
      else
        has_progress ? !check_task_progress(stack) : (@new_attachment || new_record?)
      end
    end

    # Checks an individual 'stack' against #task_progress
    def check_task_progress(stack)
      task_progress[:complete] || task_progress[stack]
    end

    # Deletes the attachment from tbhe file system, and attempts
    # to clean up the empty asset paths.
    def delete_attachment
      FileUtils.rm full_path if File.exist?(full_path)
      dir_name = File.dirname(full_path)
      default  = %w(. ..)
      while dir_name != AttachmentFu.root_path
        if (Dir.entries(dir_name) - default).empty?
          FileUtils.rm_rf dir_name
          dir_name.sub! /\/\w+$/, ''
        else
          dir_name = AttachmentFu.root_path
        end
      end
    end

    # Saves the attachment to the file system. It also processes
    # or queues the attachment for processing.
    def save_attachment
      return if @temp_path.nil?
      old_path = File.expand_path(full_path_for(@temp_path))
      return if old_path.nil?
      unless old_path == full_path
        FileUtils.mkdir_p(File.dirname(full_path))
        FileUtils.mv(old_path, full_path)
      end
      File.chmod(0644, full_path)
      @temp_path = nil # if a task tries to re-save, we don't want to re-store the attachment
      queued_attachment ? queue_processing : process
      @new_attachment = nil
    end
  
    # Could be a string, Pathname, Tempfile, who knows?
    def full_path_for(path)
      if path.respond_to?(:path)
        path.path
      elsif path.respond_to?(:realpath)
        path.realpath.to_s
      elsif path
        path.to_s
      end
    end
  
    # Could be a string, Pathname, Tempfile, who knows?
    def basename_for(path)
      if path.respond_to?(:basename)
        path.basename.to_s
      else
        File.basename(path.respond_to?(:path) ? path.path : path)
      end
    end
  
    def strip_filename(value)
      value.strip!
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      value.gsub! /^.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore or periods with underscore
      value.gsub! /[^\w\.\-]/, '_'
    end

    # Needed to tell the difference between an attachment that has just been saved, 
    # vs one saved in a previous request or object instantiation.
    def set_new_attachment
      @new_attachment = true
    end
  end
end