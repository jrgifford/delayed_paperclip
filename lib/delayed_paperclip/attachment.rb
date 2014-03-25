module DelayedPaperclip
  module Attachment

    def self.included(base)
      base.send :include, InstanceMethods
      base.send :attr_accessor, :job_is_processing
      base.alias_method_chain :post_processing, :delay
      base.alias_method_chain :post_processing=, :delay
      base.alias_method_chain :save, :prepare_enqueueing
      base.alias_method_chain :reprocess!, :processing_flag
    end

    module InstanceMethods

      def delayed_options
        @options[:delayed]
      end

      # Attr accessor in Paperclip
      def post_processing_with_delay
        !delay_processing? || split_processing?
      end

      def post_processing_with_delay=(value)
        @post_processing_with_delay = value
      end

      # if nil, returns whether it has delayed options
      # if set, then it returns
      def delay_processing?
        if @post_processing_with_delay.nil?
          !!delayed_options
        else
          !@post_processing_with_delay
        end
      end

      def split_processing?
        options[:only_process] &&
          options[:only_process] !=
            options[:delayed][:only_process]
      end

      def processing?
        column_name = :"#{@name}_processing?"
        @instance.respond_to?(column_name) && @instance.send(column_name)
      end

      def processing_style?(style)
        return false if !processing?

        !split_processing? || delayed_options[:only_process].include?(style)
      end

      def process_delayed!
        self.job_is_processing = true
        self.post_processing = true
        reprocess!(*delayed_options[:only_process])
        self.job_is_processing = false
      end

      def processing_image_url
        processing_image_url = delayed_options[:processing_image_url]
        processing_image_url = processing_image_url.call(self) if processing_image_url.respond_to?(:call)
        processing_image_url
      end

      def save_with_prepare_enqueueing
        was_dirty = @dirty

        save_without_prepare_enqueueing.tap do
          if delay_processing? && was_dirty
            instance.prepare_enqueueing_for name
          end
        end
      end

      def reprocess_without_delay!(*style_args)
        @post_processing_with_delay = true
        reprocess!(*style_args)
      end

      def reprocess_with_processing_flag!(*args)
        if @instance.respond_to?("#{@name}_processing=")
          @instance.send("#{@name}_processing=", false)
        end
        reprocess_without_processing_flag! *args
      end
    end
  end
end
