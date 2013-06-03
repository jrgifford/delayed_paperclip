module DelayedPaperclip
  module Attachment

    def self.included(base)
      base.extend(ClassMethods)
      base.send :include, InstanceMethods
      base.send :attr_accessor, :job_is_processing
      base.alias_method_chain :post_processing, :delay
      base.alias_method_chain :post_processing=, :delay
      base.alias_method_chain :save, :prepare_enqueueing
      base.alias_method_chain :after_flush_writes, :processing
      base.alias_method_chain :reprocess!, :save_options
    end

    module ClassMethods
      def save_only_process_option(styles)
        @saved_only_process = styles
      end

      def only_process_option
        @saved_only_process
      end
    end

    module InstanceMethods

      def post_processing_with_delay
        !delay_processing?
      end

      def post_processing_with_delay=(value)
        @post_processing_with_delay = value
      end

      def delayed_options
        @instance.class.attachment_definitions[@name][:delayed]
      end

      def delay_processing?
        if @post_processing_with_delay.nil?
          !!delayed_options
        else
           !@post_processing_with_delay
        end
      end

      def processing?
        @instance.send(:"#{@name}_processing?")
      end

      # Take direct styles from reprocess!
      # Use delayed_options if direct argument does not exist
      def process_delayed!
        self.job_is_processing = true
        self.post_processing = true
        reprocess!(*delayed_options[:only_process])
        reset_only_process unless self.class.only_process_option.nil?
        self.job_is_processing = false
      end

      def reset_only_process
        @instance.class.attachment_definitions[@name][:delayed][:only_process] = self.class.only_process_option
        self.class.save_only_process_option(nil)
      end

      def after_flush_writes_with_processing(*args)
        after_flush_writes_without_processing(*args)

        # update_column is available in rails 3.1 instead we can do this to update the attribute without callbacks

        # instance.update_column("#{name}_processing", false) if instance.respond_to?(:"#{name}_processing?")
        if instance.respond_to?(:"#{name}_processing?")
          instance.send("#{name}_processing=", false)
          instance.class.update_all({ "#{name}_processing" => false }, instance.class.primary_key => instance.id)
        end
      end

      def save_with_prepare_enqueueing
        was_dirty = @dirty

        save_without_prepare_enqueueing.tap do
          if delay_processing? && was_dirty
            instance.prepare_enqueueing_for name
          end
        end
      end

      def reprocess_with_save_options!(*style_args)

        unless caller.collect {|c| c[/`([^']*)'/, 1]}.include?("process_delayed!")
          if delayed_options
            self.class.save_only_process_option(delayed_options[:only_process])
            @instance.class.attachment_definitions[@name][:delayed][:only_process] = style_args
          end
        end

        reprocess_without_save_options!(*style_args)
      end

      def reprocess_without_delay!(*style_args)
        @post_processing_with_delay = true
        reprocess!(*style_args)
      end

    end
  end
end
