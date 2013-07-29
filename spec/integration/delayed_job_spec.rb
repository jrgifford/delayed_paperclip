require 'spec_helper'
require 'delayed_job'

Delayed::Worker.backend = :active_record

describe "Delayed Job" do

  before :all do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::DelayedJob
    build_delayed_jobs
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
      Delayed::Job.last.payload_object.perform
    end
  end

  def process_jobs
    Delayed::Worker.new.work_off
  end

  def jobs_count
    Delayed::Job.count
  end

  def build_delayed_jobs
    ActiveRecord::Base.connection.create_table :delayed_jobs, :force => true do |table|
      table.integer  :priority, :default => 0      # Allows some jobs to jump to the front of the queue
      table.integer  :attempts, :default => 0      # Provides for retries, but still fail eventually.
      table.text     :handler                      # YAML-encoded string of the object that will do work
      table.string   :last_error                   # reason for last failure (See Note below)
      table.datetime :run_at                       # When to run. Could be Time.now for immediately, or sometime in the future.
      table.datetime :locked_at                    # Set when a client is working on this object
      table.datetime :failed_at                    # Set when all retries have failed (actually, by default, the record is deleted instead)
      table.string   :locked_by                    # Who is working on this object (if locked)
      table.string   :queue
      table.timestamps
    end
  end
end