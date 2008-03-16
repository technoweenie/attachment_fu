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
  # joined with #attachment_path to get the full path
  def self.root_path
    @root_path ||= File.expand_path(defined?(RAILS_ROOT) ? RAILS_ROOT : File.dirname(__FILE__))
  end
  
  def self.root_path=(value)
    @root_path = value
  end

  def self.setup(klass)
    class << klass
      def is_attachment(options = {}, &block)
        include AttachmentFu
        self.root_path        = options[:root] || root_path || AttachmentFu.root_path
        self.attachment_path  = options[:path] || attachment_path || File.join("public", table_name)
        self.attachment_tasks(&block)
      end
    end
  end
  
  def self.included(base)
    class << base
      attr_writer :attachment_tasks
      
      def attachment_tasks(&block)
        @attachment_tasks ||= superclass.respond_to?(:attachment_tasks) ? superclass.attachment_tasks.copy(&block) : AttachmentFu::Tasks.new(self, &block)
      end
    end
    base.send :attr_reader,   :temp_path
    base.send :class_inheritable_accessor, :attachment_path
    base.send :class_inheritable_accessor, :root_path
    base.before_create :set_new_attachment
    base.after_save    :save_attachment
    base.after_destroy :delete_attachment
  end
  
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

  def full_filename
    return nil if new_record?
    File.join(root_path, attachment_path, *partitioned_path(filename))
  end
  
  def temp_path=(value)
    self.size       = value.is_a?(String) || !value.respond_to?(:size) ? File.size(value) : value.size
    self.filename ||= basename_for value
    @temp_path      = value
  end

  def process_task?(stack)
    has_progress  = respond_to?(:task_progress)
    if respond_to?(:processed_at)
      return false if processed_at
      !has_progress || !processed_task?(stack)\
    else
      has_progress ? !processed_task?(stack) : (@new_attachment || new_record?)
    end
  end

protected
  def processed_task?(stack)
    task_progress[:complete] || task_progress[stack]
  end
    
  def delete_attachment
    FileUtils.rm full_filename if File.exist?(full_filename)
    dir_name = File.dirname(full_filename)
    default  = %w(. ..)
    while dir_name != root_path
      if (Dir.entries(dir_name) - default).empty?
        FileUtils.rm_rf dir_name
        dir_name.sub! /\/\w+$/, ''
      else
        dir_name = root_path
      end
    end
  end
  def save_attachment
    old_path = full_path_for @temp_path
    return if old_path.nil?
    FileUtils.mkdir_p(File.dirname(full_filename))
    FileUtils.mv(old_path, full_filename)
    File.chmod(0644, full_filename)
    self.class.attachment_tasks.process(self)
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
  
  def set_new_attachment
    @new_attachment = true
  end
end