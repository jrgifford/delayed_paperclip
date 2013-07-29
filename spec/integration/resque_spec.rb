require 'spec_helper'
require 'resque'

describe "Resque" do

  before :all do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
    Resque.remove_queue(:paperclip)
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
      DelayedPaperclip::Jobs::Resque.perform(dummy.class.name, dummy.id, :image)
    end
  end

  def process_jobs
    worker = Resque::Worker.new(:paperclip)
    worker.process
  end

  def jobs_count
    Resque.size(:paperclip)
  end

end