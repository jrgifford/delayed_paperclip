require 'uri'
require 'paperclip/url_generator'

module DelayedPaperclip
  class UrlGenerator < ::Paperclip::UrlGenerator
    # This method is a mess
    def most_appropriate_url(style = nil)
      if @attachment.processing_style?(style)
        if @attachment.original_filename.nil? || delayed_default_url?(style)

          if @attachment.delayed_options.nil? ||
            @attachment.processing_image_url.nil? ||
            !@attachment.processing?
            default_url
          else
            @attachment.processing_image_url
          end

        else
          @attachment_options[:url]
        end
      else
        super()
      end
    end

    def timestamp_possible?
      delayed_default_url? ? false : super
    end

    def delayed_default_url?(style = nil)
      return false if @attachment.job_is_processing
      return false if @attachment.dirty?
      return false if not @attachment.delayed_options.try(:[], :url_with_processing)
      return false if not processing?(style)
      true
    end

    private

    def processing?(style)
      return true if @attachment.processing?
      return @attachment.processing_style?(style) if style
    end
  end
end
