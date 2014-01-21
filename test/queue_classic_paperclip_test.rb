require 'test_helper'
require 'base_delayed_paperclip_test'
require 'queue_classic'

class QueueClassicPaperclipTest < Test::Unit::TestCase
  include BaseDelayedPaperclipTest

  def setup
    super
    # Make sure that we just test QueueClassic in here
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::QueueClassic
    @queue = QC::Queue.new 'paperclip'
    @queue.delete_all
  end

  def process_jobs
    @worker ||= QC::Worker.new q_name: 'paperclip'
    @worker.work while @queue.count > 0
  end

  def jobs_count
    @queue.count
  end

  def test_perform_job
    dummy = Dummy.new image: File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    dummy.image = File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    Paperclip::Attachment.any_instance.expects(:reprocess!)
    dummy.save!
    DelayedPaperclip::Jobs::QueueClassic.perform(dummy.class.name, dummy.id, :image)
  end
end
