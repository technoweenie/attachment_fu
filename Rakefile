require 'rake'
require "rake/rdoctask"
require 'rake/gempackagetask'
require File.join(File.dirname(__FILE__), 'spec', 'spec_helper')
require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

rdoc_files = FileList["{bin,lib,example_configs}/**/*"].to_a
extra_rdoc_files = %w(README COPYRIGHT RELEASES CHANGELOG)

Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.rdoc_files.include(rdoc_files, extra_rdoc_files)
  rd.rdoc_dir = "doc/rdoc/"
end

desc "Run all examples with RCov"
Spec::Rake::SpecTask.new(:rcov) do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
  t.rcov_dir = "doc/rcov"
end

desc "Run all specs"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.rcov = false
end

desc "Generate RSpec Report"
task :rspec_report => [:clobber_rspec_report] do
  files = FileList["spec/**/*.rb"].to_s
  %x(spec #{files} --format html:doc/rspec_report.html)
end

task :clobber_rspec_report do
  %x(rm -rf doc/rspec_report.html)
end

desc "Generate all documentation"
task :generate_documentation => [:clobber_documentation, :rdoc, :rcov, :rspec_report]

desc "Remove all documentation"
task :clobber_documentation => [:clobber_rdoc, :clobber_rcov, :clobber_rspec_report]

desc "Build Release"
task :build_release => [:pre_commit, :generate_documentation, :repackage] do
  %x(mv pkg gem)
end

desc "Run this before commiting"
task :pre_commit => [:verify_rcov]