Gem::Specification.new do |s|
  s.name			  = %q{attachment_fu}
  s.authors			  = ["Rick Olson", "Steven Pothoven", "Eduard Martini"]
  s.summary			  = %q{attachment_fu as a gem}
  s.description		  = %q{This is a fork of Steven Pothoven's attachment_fu fixing some validation errors.}
  s.email			  = %q{eduard.martini@gmail.com}
  s.homepage		  = %q{http://github.com/eduardm/attachment_fu}
  s.version			  = "3.2.19"
  s.date			  = %q{2017-01-02}

  s.files			  = Dir.glob("{lib,vendor}/**/*") + %w( CHANGELOG LICENSE README.rdoc amazon_s3.yml.tpl rackspace_cloudfiles.yml.tpl )
  s.extra_rdoc_files  = ["README.rdoc"]
  s.rdoc_options	  = ["--inline-source", "--charset=UTF-8"]
  s.require_paths	  = ["lib"]
  s.rubyforge_project = "nowarning"
  s.rubygems_version  = %q{1.8.29}

  if s.respond_to? :specification_version then
    s.specification_version = 2
  end
end
