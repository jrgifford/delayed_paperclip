require 'delayed_job'

module DelayedPaperclip
  module Jobs
    class DelayedJob < Struct.new(:instance_klass, :instance_id, :attachment_name)

      if Gem.loaded_specs['delayed_job'].version >= Gem::Version.new("2.1.0") # this is available in newer versions of DelayedJob. Using the newee Job api thus.

        def self.enqueue_delayed_paperclip(instance_klass, instance_id, attachment_name)
          ::Delayed::Job.enqueue(
            :payload_object => new(instance_klass, instance_id, attachment_name),
            :priority => instance_klass.constantize.paperclip_definitions[attachment_name][:delayed][:priority].to_i
          )
        end

      else

        def self.enqueue_delayed_paperclip(instance_klass, instance_id, attachment_name)
          ::Delayed::Job.enqueue(
            new(instance_klass, instance_id, attachment_name),
            instance_klass.constantize.paperclip_definitions[attachment_name][:delayed][:priority].to_i
          )
        end

      end

      def perform
        DelayedPaperclip.process_job(instance_klass, instance_id, attachment_name)
      end
    end
  end
end