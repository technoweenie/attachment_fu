# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{attachment_fu}
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Technoweenie"]
  s.date = %q{2010-12-28}
  s.description = %q{Adds has_attachment (file store) properties to ActiveRecord.  Supports local file, file-in-db, S3 and Cloudfiles backends.}
  s.email = %q{git://github.com/mperham/deadlock_retry.git}
  s.files = ["README", "init.rb", "CHANGELOG"] + Dir["lib/**/*.rb"]
  s.has_rdoc = false
  s.homepage = %q{http://github.com/zendesk/attachment_fu}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Adds has_attachment properties to ActiveRecord}
end
