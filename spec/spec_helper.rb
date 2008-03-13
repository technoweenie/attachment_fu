require 'rubygems'

dir = File.dirname(__FILE__)
rails_app_spec = "#{dir}/../../../../config/environment.rb"
vendor_rspec   = "#{dir}/../../rspec/lib"

if File.exist?(vendor_rspec)
  $:.unshift vendor_rspec
else
  gem 'rspec'
end

if File.exist?(rails_app_spec)
  require rails_app_spec
else
  raise "TODO: attempt to load activerecord and activesupport from gems"
  # also, establish connection with sqlite3 or use DB env var as path to database.yml
end

$:.unshift "#{dir}/../lib"

require 'ruby-debug'
require 'spec'
require 'attachment_fu'

module AttachmentFu
  module FauxAsset
    def self.extended(base)
      base.set_table_name :afu_spec_assets
    end
    
    def setup_spec_env
      connection.create_table :afu_spec_assets do |t|
        t.integer :size
        t.string  :filename
        t.string  :content_type
      end
    end
    
    def drop_spec_env
      connection.drop_table :afu_spec_assets
    end
  end
end

AttachmentFu.root_path = File.join(File.dirname(__FILE__), 'assets')

Debugger.start