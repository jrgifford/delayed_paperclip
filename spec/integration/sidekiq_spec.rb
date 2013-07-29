require 'spec_helper'
require 'sidekiq'

describe "Sidekiq" do

  before :all do
    Sidekiq.logger.level = Logger::ERROR
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Sidekiq
    Sidekiq::Queue.new(:paperclip).clear
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
      DelayedPaperclip::Jobs::Sidekiq.new.perform(dummy.class.name, dummy.id, :image)
    end
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

end