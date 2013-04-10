# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name			  = %q{pothoven-attachment_fu}
  s.authors			  = ["Rick Olson", "Steven Pothoven"]
  s.summary			  = %q{attachment_fu as a gem}
  s.description		  = %q{This is a fork of Rick Olson’s attachment_fu adding Ruby 1.9 and Rails 3.2 support as well as some other enhancements.}
  s.email			  = %q{steven@pothoven.net}
  s.homepage		  = %q{http://github.com/pothoven/attachment_fu}
  s.version			  = "3.2.7"
  s.date			  = %q{2013-04-10}

  s.files			  = Dir.glob("{lib,vendor}/**/*") + %w( CHANGELOG LICENSE README amazon_s3.yml.tpl rackspace_cloudfiles.yml.tpl )
  s.extra_rdoc_files  = ["README"]
  s.rdoc_options	  = ["--inline-source", "--charset=UTF-8"]
  s.require_paths	  = ["lib"]
  s.rubyforge_project = "nowarning"
  s.rubygems_version  = %q{1.3.5}

  if s.respond_to? :specification_version then
    s.specification_version = 2
  end
end
