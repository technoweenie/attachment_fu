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
    # The \table schema should look like this:
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
      include AttachmentFu
      self.queued_attachment = options[:queued]
      self.attachment_path   = options[:path] || attachment_path || File.join("public", table_name)
      self.attachment_tasks(&block)
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
  
  def self.included(base)
    class << base
      attr_writer :attachment_tasks
      
      def attachment_tasks(&block)
        @attachment_tasks ||= superclass.respond_to?(:attachment_tasks) ? superclass.attachment_tasks.copy(&block) : AttachmentFu::Tasks.new(self, &block)
      end
    end
    base.send :attr_reader,   :temp_path
    base.send :class_inheritable_accessor, :queued_attachment
    base.send :class_inheritable_accessor, :attachment_path
    base.before_create :set_new_attachment
    base.after_save    :save_attachment
    base.after_destroy :delete_attachment
  end
  
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
      self.temp_path = Tempfile.new filename do |f|
        f << file_data.read
      end
    else
      self.temp_path = file_data
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
    return nil if new_record?
    ("%08d" % attachment_path_id).scan(/..../) + args
  end

  # Returns the full path for an attachment
  def full_filename
    return nil if new_record?
    File.join(AttachmentFu.root_path, attachment_path, *partitioned_path(filename))
  end
  
  # Sets the path to the attachment about to be saved.  Could be a string path to a file, 
  # a Pathname referencing a file, or a Tempfile.
  def temp_path=(value)
    self.size       = value.is_a?(String) || !value.respond_to?(:size) ? File.size(value) : value.size
    self.filename ||= basename_for value
    @temp_path      = value
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
  def process
    if has_progress = respond_to?(:task_progress)
      self.task_progress ||= {}
    end
    self.class.attachment_tasks.each do |stack_item|
      if process_task?(stack_item)
        begin
          task, options = stack_item
          task.call self, options
          if has_progress then task_progress[stack_item] = true end
        rescue Object
          if has_progress
            task_progress[stack_item] = $!
            return
          else
            raise $!
          end
        end
      end
    end
    if has_progress
      self.task_progress = {:complete => true}
    end
    self.processed_at = Time.now.utc if respond_to?(:processed_at)
  end
  
  # Returns true/false if an attachment has been processed.
  def processed?
    return true if respond_to?(:processed_at)  && processed_at
    return true if respond_to?(:task_progress) && task_progress[:complete]
    !self.class.attachment_tasks.any? { |s| process_task?(s) }
  end

protected
  # Checks to see if the given 'stack' (see AttachmentFu::Tasks) needs to be
  # run.  
  def process_task?(stack)
    has_progress  = respond_to?(:task_progress)
    if respond_to?(:processed_at)
      return false if processed_at
      !has_progress || !check_task_progress(stack)\
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
    FileUtils.rm full_filename if File.exist?(full_filename)
    dir_name = File.dirname(full_filename)
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
    old_path = full_path_for @temp_path
    return if old_path.nil?
    FileUtils.mkdir_p(File.dirname(full_filename))
    FileUtils.mv(old_path, full_filename)
    File.chmod(0644, full_filename)
    queued_attachment ? queue_processing : process
    @temp_path = @new_attachment = nil
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