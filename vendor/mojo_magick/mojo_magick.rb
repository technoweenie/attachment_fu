require File::expand_path(File::join(File::dirname(__FILE__), 'image_resources'))
# MojoMagick is a stateless set of module methods which present a convient interface
# for accessing common tasks for ImageMagick command line library.
#
# MojoMagick is specifically designed to be efficient and simple and most importantly
# to not leak any memory. For complex image operations, you will find MojoMagick limited.
# You might consider the venerable MiniMagick or RMagick for your purposes if you care more
# about ease of use rather than speed and memory management.

# all commands raise "MojoMagick::MojoFailed" if command fails (ImageMagick determines command success status)
module MojoMagick

  VERSION ||= "0.0.2"

  class MojoMagickException < StandardError; end
  class MojoError < MojoMagickException; end
  class MojoFailed < MojoMagickException; end

  # enable resource limiting functionality
  extend ImageMagickResources::ResourceLimits

  def MojoMagick::windows?
    !(RUBY_PLATFORM =~ /win32/).nil?
  end

  def MojoMagick::raw_command(command, args, options = {})
    # this suppress error messages to the console in Windows
    err_pipe = windows? ? "2>nul" : ""
    begin
      execute = "#{command} #{get_limits_as_params} #{args} #{err_pipe}"
      retval = `#{execute}`
    # guarantee that only MojoError exceptions are raised here
    rescue Exception => e
      raise MojoError, "#{e.class}: #{e.message}"
    end
    if $? && !$?.success?
      err_msg = options[:err_msg] || "MojoMagick command failed: #{command}."
      raise(MojoFailed, "#{err_msg} (Exit status: #{$?.exitstatus})\n  Command: #{execute}")
    end
    retval
  end

  def MojoMagick::shrink(source_file, dest_file, options)
    opts = options.dup
    opts.delete(:expand_only)
    MojoMagick::resize(source_file, dest_file, opts.merge(:shrink_only => true))
  end

  def MojoMagick::expand(source_file, dest_file, options)
    opts = options.dup
    opts.delete(:shrink_only)
    MojoMagick::resize(source_file, dest_file, opts.merge(:expand_only => true))
  end

  # resizes an image and returns the filename written to
  # options:
  #   :width / :height => scale to these dimensions
  #   :scale => pass scale options such as ">" to force shrink scaling only or "!" to force absolute width/height scaling (do not preserve aspect ratio)
  #   :percent => scale image to this percentage (do not specify :width/:height in this case)
  def MojoMagick::resize(source_file, dest_file, options)
    retval = nil
    scale_options = []
    scale_options << '">"' unless options[:shrink_only].nil?
    scale_options << '"<"' unless options[:expand_only].nil?
    scale_options << '"!"' unless options[:absolute_aspect].nil?
    scale_options = scale_options.join(' ')
    if !options[:width].nil? && !options[:height].nil?
      retval = raw_command("convert", "\"#{source_file}\" -resize #{options[:width]}X#{options[:height]}#{scale_options} \"#{dest_file}\"")
    elsif !options[:percent].nil?
      retval = raw_command("convert", "\"#{source_file}\" -resize #{options[:percent]}%#{scale_options} \"#{dest_file}\"")
    else
      raise MojoMagickError, "Unknown options for method resize: #{options.inspect}"
    end
    dest_file
  end

  # returns an empty hash or a hash with :width and :height set (e.g. {:width => INT, :height => INT})
  # raises MojoFailed when results are indeterminate (width and height could not be determined)
  def MojoMagick::get_image_size(source_file)
    # returns width, height of image if available, nil if not
    retval = raw_command("identify", "-format \"w:%w h:%h\" \"#{source_file}\"")
    return {} if !retval
    width = retval.match(%r{w:([0-9]+) })
    width = width ? width[1].to_i : nil
    height = retval.match(%r{h:([0-9]+)})
    height = height ? height[1].to_i : nil
    raise(MojoFailed, "Indeterminate results in get_image_size: #{source_file}") if !height || !width
    {:width=>width, :height=>height}
  end
end # MojoMagick


