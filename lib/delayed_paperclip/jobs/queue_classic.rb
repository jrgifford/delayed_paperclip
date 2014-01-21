require 'queue_classic'

module DelayedPaperclip
  module Jobs
    class QueueClassic
      @queue = ::QC::Queue.new 'paperclip'

      def self.enqueue_delayed_paperclip(instance_klass, instance_id, attachment_name)
        @queue.enqueue "#{self}.perform", instance_klass, instance_id, attachment_name
      end

      def self.perform(instance_klass, instance_id, attachment_name)
        DelayedPaperclip.process_job instance_klass, instance_id, attachment_name
      end
    end
  end
end
