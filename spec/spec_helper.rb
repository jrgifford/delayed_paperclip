$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rails'
require 'active_record'
require 'rspec'
require 'mocha/api'

require 'paperclip/railtie'
Paperclip::Railtie.insert

require 'delayed_paperclip/railtie'
DelayedPaperclip::Railtie.insert

# Connect to sqlite
ActiveRecord::Base.establish_connection(
  "adapter" => "sqlite3",
  "database" => ":memory:"
)

# Path for filesystem writing
ROOT = Pathname(File.expand_path(File.join(File.dirname(__FILE__), '..')))

FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures")
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
Paperclip.logger = ActiveRecord::Base.logger

RSpec.configure do |config|
  config.mock_with :mocha

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

Dir["./spec/integration/examples/*.rb"].sort.each {|f| require f}

# Reset table and class with image_processing column or not
def reset_dummy(options = {})
  options[:with_processed] = true unless options.key?(:with_processed)
  build_dummy_table(options[:with_processed])
  reset_class("Dummy", options)
end

# Dummy Table for images
# with or without image_processing column
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
  # setup class and include paperclip
  options[:paperclip] = {} if options[:paperclip].nil?
  ActiveRecord::Base.send(:include, Paperclip::Glue)
  Object.send(:remove_const, class_name) rescue nil

  # Set class as a constant
  klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))

  # Setup class with paperclip and delayed paperclip
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

  Rails.stubs(:root).returns(Pathname.new(ROOT).join('spec', 'tmp'))
  klass.reset_column_information
  klass
end
