require 'spec_helper'
require 'queue_classic'

describe "Queue Classic" do
  before :all do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::QueueClassic
    @queue = QC::Queue.new 'paperclip'
    @queue.delete_all
  end

  let(:dummy) { Dummy.new(:image => File.open("#{ROOT}/spec/fixtures/12k.png")) }

  describe "integration tests" do
    include_examples "base usage"
  end

  describe "perform job" do
    before :each do
      DelayedPaperclip.options[:url_with_processing] = true
      reset_dummy
    end

    it "performs a job" do
      dummy.image = File.open("#{ROOT}/spec/fixtures/12k.png")
      Paperclip::Attachment.any_instance.expects(:reprocess!)
      dummy.save!
      DelayedPaperclip::Jobs::QueueClassic.perform(dummy.class.name, dummy.id, :image)
    end
  end

  def process_jobs
    @worker ||= QC::Worker.new q_name: 'paperclip'
    @worker.work while @queue.count > 0
  end

  def jobs_count
    @queue.count
  end
end
