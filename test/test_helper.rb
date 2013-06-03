require 'rubygems'
require 'test/unit'
require 'mocha'
require 'active_record'
require 'logger'
require 'sqlite3'
require 'paperclip/railtie'
require 'debugger'

Paperclip::Railtie.insert

ROOT       = File.join(File.dirname(__FILE__), '..')
RAILS_ROOT = ROOT
$LOAD_PATH << File.join(ROOT, 'lib')

require 'delayed_paperclip/railtie'
DelayedPaperclip::Railtie.insert

class Test::Unit::TestCase
  def setup
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :root => ROOT, :env => 'test'))
    end
  end
end

FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures")
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])
Paperclip.logger = ActiveRecord::Base.logger

# def reset_dummy(options = {})
#   reset_dummy(options)
#   Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
# end

def reset_dummy(options = {})
  options[:with_processed] = true unless options.key?(:with_processed)
  build_dummy_table(options[:with_processed])
  reset_class("Dummy", options)
end

def build_dummy_table(with_processed)
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |t|
    t.string   :name
    t.string   :image_file_name
    t.string   :image_content_type
    t.integer  :image_file_size
    t.datetime :image_updated_at
    t.boolean(:image_processing, :default => false) if with_processed
  end
end

def reset_class(class_name, options)
  options[:paperclip] = {} if options[:paperclip].nil?
  ActiveRecord::Base.send(:include, Paperclip::Glue)
  Object.send(:remove_const, class_name) rescue nil
  klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))
  klass.class_eval do
    include Paperclip::Glue
    has_attached_file  :image, options[:paperclip]

    options.delete(:paperclip)
    process_in_background :image, options if options[:with_processed]
    after_update :reprocess if options[:with_after_update_callback]

    def reprocess
      image.reprocess!
    end

  end
  klass.reset_column_information
  klass
end
