require 'test_helper'
require 'base_delayed_paperclip_test'
require 'sidekiq'

class SidekiqPaperclipTest < Test::Unit::TestCase
  include BaseDelayedPaperclipTest

  def setup
    super
    # Make sure that we just test Sidekiq in here
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Sidekiq
    Sidekiq::Queue.new(:paperclip).clear
  end

  def process_jobs
    Sidekiq::Queue.new(:paperclip).each do |job|
      worker = job.klass.constantize.new
      args   = job.args
      begin
        worker.perform(*args)
      rescue # Assume sidekiq handle exception properly
      end
      job.delete
    end
  end

  def jobs_count
    Sidekiq::Queue.new(:paperclip).size
  end

  def test_perform_job
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.image = File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    Paperclip::Attachment.any_instance.expects(:reprocess!)
    dummy.save!
    DelayedPaperclip::Jobs::Sidekiq.new.perform(dummy.class.name, dummy.id, :image)
  end

end
