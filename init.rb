require 'tempfile'

Tempfile.class_eval do
  # overwrite so tempfiles keep the basename extension
  def make_tmpname(basename, n)
    ext = nil
    sprintf("%s%d-%d%s", basename.gsub(/\.\w+$/) { |s| ext = s; '' }, $$, n, ext)
  end
end

ActiveRecord::Base.send(:extend, Technoweenie::AttachmentFu::ActMethods)