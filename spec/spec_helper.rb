require 'rubygems'

RAILS_ENV = 'test'
dir = File.dirname(__FILE__)
rails_app      = "#{dir}/../../../../config/environment.rb"
vendor_rspec   = "#{dir}/../../rspec/lib"

if File.exist?(vendor_rspec)
  $:.unshift vendor_rspec
else
  gem 'rspec'
end

if File.exist?(rails_app)
  require rails_app
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
      connection.create_table :afu_spec_assets, :force => true do |t|
        t.belongs_to :parent
        t.integer :size
        t.integer :width
        t.integer :height
        t.string  :filename
        t.string  :content_type
        t.string  :thumbnail
      end
    end

    def drop_spec_env
      connection.drop_table :afu_spec_assets
    end

    module InstanceMethods
      def queued?
        @queued
      end

      def queue_processing
        @queued = true
      end
    end
  end
  
  module SetupMethods
    def is_faux_attachment(*args, &block)
      extend AttachmentFu::FauxAsset
      is_attachment(*args, &block)
      send :include, AttachmentFu::FauxAsset::InstanceMethods
    end
  end
end

AttachmentFu.root_path = File.expand_path(File.join(File.dirname(__FILE__), 'assets'))

config_rb = File.join(File.dirname(__FILE__), 'config.rb')
if !File.exist?(config_rb)
  open config_rb, 'w' do |f|
    f.write <<-END_CONFIG
# Replace this with your custom settings.
# This file is ignored in .gitignore

# I'd recommend using ParkPlace for local S3 testing.
# http://code.whytheluckystiff.net/parkplace
#
#AttachmentFu::Tasks::S3.connect(
#  :server            => "localhost", 
#  :port              => 3002,
#  :access_key_id     => "ACCESS", 
#  :secret_access_key => "SECRET")
    END_CONFIG
  end
end

require config_rb

Debugger.start