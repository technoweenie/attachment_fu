require 'rake/testtask'
require 'rubygems'
require 'bundler'
require "appraisal"

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the attachment_fu plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
