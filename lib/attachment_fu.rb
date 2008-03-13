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

  def self.init
    class << ActiveRecord::Base
      def is_attachment(options = {})
        include AttachmentFu
        self.attachment_path = options[:path] || File.join("public", table_name)
      end
    end
  end
  
  def self.included(base)
    base.send :attr_reader, :temp_path
    base.send :class_inheritable_accessor, :attachment_path
    base.after_save    :save_attachment
    base.after_destroy :delete_attachment
  end
  
  def filename=(value)
    if value
      value.strip!
      # NOTE: File.basename doesn't work right with Windows paths on Unix
      # get only the filename, not the whole path
      value.gsub! /^.*(\\|\/)/, ''
      # Finally, replace all non alphanumeric, underscore or periods with underscore
      value.gsub! /[^\w\.\-]/, '_'
    end
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
  # TODO: Allow it to work with Merb tempfiles too.
  #def uploaded_data=(file_data)
  #  return nil if file_data.nil? || file_data.size == 0 
  #  self.content_type = file_data.content_type
  #  self.filename     = file_data.original_filename
  #  if file_data.is_a?(StringIO)
  #    file_data.rewind
  #    self.temp_path = Tempfile.open filename do |f|
  #      f << file_data.read
  #    end
  #  else
  #    self.temp_path = file_data
  #  end
  #end

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
    File.join(AttachmentFu.root_path, attachment_path, *partitioned_path(filename))
  end
  
  def temp_path=(value)
    self.size = value.is_a?(String) || !value.respond_to?(:size) ? File.size(value) : value.size
    self.filename ||= begin
      if value.respond_to?(:basename)
        value.basename.to_s
      elsif value.respond_to?(:path)
        File.basename(value.path)
      else
        File.basename(value)
      end
    end
    @temp_path = value
  end
  
  def delete_attachment
    FileUtils.rm full_filename if File.exist?(full_filename)
  end

protected
  def save_attachment
    old_path = if @temp_path.respond_to?(:path)
      @temp_path.path
    elsif @temp_path.respond_to?(:realpath)
      @temp_path.realpath.to_s
    elsif @temp_path
      @temp_path.to_s
    end
    return if old_path.nil?
    FileUtils.mkdir_p(File.dirname(full_filename))
    FileUtils.mv(old_path, full_filename)
    File.chmod(0644, full_filename)
    @temp_path = nil
  end
end