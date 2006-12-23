require 'tempfile'

class Tempfile
  # overwrite so tempfiles have no extension
  def make_tmpname(basename, n)
    sprintf("%s%d-%d", basename, $$, n)
  end
end

ActiveRecord::Base.send(:extend, Technoweenie::AttachmentFu::ActMethods)