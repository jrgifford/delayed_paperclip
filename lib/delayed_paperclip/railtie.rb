require 'paperclip'
require 'delayed_paperclip'

module DelayedPaperclip
  if defined? Rails::Railtie
    require 'rails'

    # On initialzation, include DelayedPaperclip
    class Railtie < Rails::Railtie
      initializer 'delayed_paperclip.insert_into_active_record' do
        ActiveSupport.on_load :active_record do
          DelayedPaperclip::Railtie.insert
        end
      end
    end
  end

  class Railtie

    # Glue includes DelayedPaperclip Class Methods and Instance Methods into ActiveRecord
    # Attachment and URL Generator extends Paperclip
    def self.insert
      ActiveRecord::Base.send(:include, DelayedPaperclip::Glue)
      Paperclip::Attachment.send(:include, DelayedPaperclip::Attachment)
      Paperclip::UrlGenerator.send(:include, DelayedPaperclip::UrlGenerator)
    end
  end
end
