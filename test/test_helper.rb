$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require File.expand_path(File.join(File.dirname(__FILE__), '../../../../config/environment.rb'))
require 'breakpoint'
require 'active_record/fixtures'
require 'action_controller/test_process'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite'])

load(File.dirname(__FILE__) + "/schema.rb")

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
$LOAD_PATH.unshift(Test::Unit::TestCase.fixture_path)

class Test::Unit::TestCase #:nodoc:
  include ActionController::TestProcess
  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
    end
  end

  def setup
    FileUtils.rm_rf File.join(File.dirname(__FILE__), 'files')
    attachment_model self.class.attachment_model
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
      att = attachment_model.create :uploaded_data => fixture_file_upload(options[:filename], options[:content_type] || 'image/png')
      att.reload unless att.new_record?
      att
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
require File.join(File.dirname(__FILE__), 'fixtures/base_attachment_tests')