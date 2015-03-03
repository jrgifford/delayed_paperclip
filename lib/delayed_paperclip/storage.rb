module DelayedPaperclip
  module Storage

    # If the style is processing, it doesn't exist yet. Otherwise, let
    # Paperclip's storage adapter determine if it exists.
    #
    # Technically the job may currently be processing and have already generated
    # some styles but this will continue to return false until all styles are
    # finished processing.
    def exists?(style_name = default_style)
      return false if processing_style?(style_name)

      super
    end

  end
end
