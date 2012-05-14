require 'rubygems'
require 'bundler'
Bundler.setup

ENV['RAILS_ENV'] = 'test'

# to-do: strip from rails 3 tests
RAILS_ROOT=File.expand_path("..", File.dirname(__FILE__))

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'active_record'
require 'active_record/fixtures'

require 'action_controller'

require 'ruby-debug'
require 'attachment_fu'
require 'mocha'
require 'logger'


config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")

db_adapter = ENV['DB']

# no db passed, try one of these fine config-free DBs before bombing.
db_adapter ||=
  begin
    require 'rubygems'
    require 'sqlite'
    'sqlite'
  rescue MissingSourceFile
    begin
      require 'sqlite3'
      'sqlite3'
    rescue MissingSourceFile
      begin
        require 'mysql'
        'mysql'
      rescue MissingSourceFile
      end
    end
  end

if db_adapter.nil?
  raise "No DB Adapter selected.  Pass the DB= option to pick one, or install Sqlite or Sqlite3."
end

ActiveRecord::Base.establish_connection(config[db_adapter])

load(File.dirname(__FILE__) + "/schema.rb")

class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  self.fixture_path = File.dirname(__FILE__) + "/fixtures"
  $LOAD_PATH.unshift(ActiveSupport::TestCase.fixture_path)

  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names)
    end
  end

  def fixture_file_upload(path, mime_type = nil, binary = false)
    fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
    file_klass = ActionController.const_defined?(:TestUploadedFile) ? ActionController::TestUploadedFile : Rack::Test::UploadedFile
    file_klass.new("#{fixture_path}#{path}", mime_type, binary)
  end

  def setup
    system("rm -Rf #{File.dirname(__FILE__) + "/../vendor/plugins/attachment_fu/test/files"}")
    DbFile.transaction { [AttachmentTest, FileAttachment, OrphanAttachment, MinimalAttachment, DbFile].each { |klass| klass.delete_all } }
    attachment_model self.class.attachment_model
  end

  def teardown
    FileUtils.rm_rf File.join(File.dirname(__FILE__), 'files')
  end

  def assert_valid(record)
    assert record.valid?, record.errors.full_messages.join("\n")
  end

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  def self.attachment_model(klass = nil)
    @attachment_model = klass if klass
    @attachment_model
  end

  def self.test_against_class(test_method, klass, subclass = false)
    define_method("#{test_method}_on_#{:sub if subclass}class") do
      klass = Class.new(klass) if subclass
      attachment_model klass
      send test_method, klass
    end
  end

  def self.test_against_subclass(test_method, klass)
    test_against_class test_method, klass, true
  end

  protected
    def upload_file(options = {})
      use_temp_file options[:filename] do |file|
        att = attachment_model.create :uploaded_data => fixture_file_upload(file, options[:content_type] || 'image/png')
        att.reload unless att.new_record?
        return att
      end
    end

    def upload_merb_file(options = {})
      use_temp_file options[:filename] do |file|
        att = attachment_model.create :uploaded_data => {"size" => file.size, "content_type" => options[:content_type] || 'image/png', "filename" => file, 'tempfile' => fixture_file_upload(file, options[:content_type] || 'image/png')}
        att.reload unless att.new_record?
        return att
      end
    end

    def use_temp_file(fixture_filename)
      temp_path = File.join('/tmp', File.basename(fixture_filename))
      FileUtils.mkdir_p File.join(fixture_path, 'tmp')
      FileUtils.cp File.join(fixture_path, fixture_filename), File.join(fixture_path, temp_path)
      yield temp_path
    ensure
      FileUtils.rm_rf File.join(fixture_path, 'tmp')
    end

    def assert_created(num = 1)
      assert_difference attachment_model.base_class, :count, num do
        if attachment_model.included_modules.include? DbFile
          assert_difference DbFile, :count, num do
            yield
          end
        else
          yield
        end
      end
    end

    def assert_not_created
      assert_created(0) { yield }
    end

    def should_reject_by_size_with(klass)
      attachment_model klass
      assert_not_created do
        attachment = upload_file :filename => '/files/rails.png'
        assert attachment.new_record?
        assert attachment.errors.on(:size)
        assert_nil attachment.db_file if attachment.respond_to?(:db_file)
      end
    end

    def assert_difference(object, method = nil, difference = 1)
      initial_value = object.send(method)
      yield
      assert_equal initial_value + difference, object.send(method)
    end

    def assert_no_difference(object, method, &block)
      assert_difference object, method, 0, &block
    end

    def attachment_model(klass = nil)
      @attachment_model = klass if klass
      @attachment_model
    end
end

require File.join(File.dirname(__FILE__), 'fixtures/attachment')
require File.join(File.dirname(__FILE__), 'base_attachment_tests')

