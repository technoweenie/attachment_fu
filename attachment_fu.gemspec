# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{attachment_fu}
  s.version = "3.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Rick Olson", "Christophe Porteneuve", "Steven Pothoven"]
  s.date = %q{2012-10-26}
  s.description = %q{This is a fork of Rick Olson’s attachment_fu adding Ruby 1.9 and Rails 3.2 support as well as some other enhancements.}
  s.email = %q{steven@pothoven.net}
  s.extra_rdoc_files = ["README"]
  s.files = %w(
    CHANGELOG
    LICENSE
    README
    Rakefile
    init.rb
    install.rb
    amazon_s3.yml.tpl
    rackspace_cloudfiles.yml.tpl
    lib/geometry.rb
    lib/technoweenie/attachment_fu/backends/cloud_file_backend.rb
    lib/technoweenie/attachment_fu/backends/db_file_backend.rb
    lib/technoweenie/attachment_fu/backends/file_system_backend.rb
    lib/technoweenie/attachment_fu/backends/s3_backend.rb
    lib/technoweenie/attachment_fu/processors/core_image_processor.rb
    lib/technoweenie/attachment_fu/processors/gd2_processor.rb
    lib/technoweenie/attachment_fu/processors/image_science_processor.rb
    lib/technoweenie/attachment_fu/processors/mini_magick_processor.rb
    lib/technoweenie/attachment_fu/processors/rmagick_processor.rb
    lib/technoweenie/attachment_fu.rb
    test/base_attachment_tests.rb
    test/basic_test.rb
    test/database.yml
    test/extra_attachment_test.rb
    test/geometry_test.rb
    test/schema.rb
    test/test_helper.rb
    test/validation_test.rb
    test/backends/db_file_test.rb
    test/backends/file_system_test.rb
    test/backends/remote/cloudfiles_test.rb
    test/backends/remote/s3_test.rb
    test/fixtures/attachment.rb
    test/fixtures/files/foo.txt
    test/fixtures/files/rails.jpg
    test/fixtures/files/rails.png
    test/fixtures/files/fake/rails.png
    test/processors/core_image_test.rb
    test/processors/gd2_test.rb
    test/processors/image_science_test.rb
    test/processors/mini_magick_test.rb
    test/processors/rmagick_test.rb
    vendor/red_artisan/core_image/processor.rb
    vendor/red_artisan/core_image/filters/color.rb
    vendor/red_artisan/core_image/filters/effects.rb
    vendor/red_artisan/core_image/filters/perspective.rb
    vendor/red_artisan/core_image/filters/quality.rb
    vendor/red_artisan/core_image/filters/scale.rb
    vendor/red_artisan/core_image/filters/watermark.rb
  )
  s.homepage = %q{http://github.com/tdd/attachment_fu}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  # s.rubyforge_project = %q{attachment_fu}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{attachment_fu with more geometries, polymorphic-based settings and JPEG quality control. }

  if s.respond_to? :specification_version then
    s.specification_version = 2
  end
end
