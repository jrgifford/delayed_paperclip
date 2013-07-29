require 'spec_helper'

describe DelayedPaperclip::Attachment do

  before :all do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
    reset_dummy
  end

  let(:dummy) { Dummy.create }

  describe "#delayed_options" do

    it "returns the specific options for delayed paperclip" do
      dummy.image.delayed_options.should == {
        :priority => 0,
        :only_process => nil,
        :url_with_processing => true,
        :processing_image_url => nil
      }
    end

  end

  describe "#post_processing_with_delay" do
    it "is true if delay_processing? is false" do
      dummy.image.stubs(:delay_processing?).returns false
      dummy.image.post_processing_with_delay.should be_true
    end

    it "is false if delay_processing? is true" do
      dummy.image.stubs(:delay_processing?).returns true
      dummy.image.post_processing_with_delay.should be_false
    end
  end

  describe "delay_processing?" do
    it "returns delayed_options existence if post_processing_with_delay is nil" do
      dummy.image.post_processing_with_delay = nil
      dummy.image.delay_processing?.should be_true
    end

    it "returns inverse of post_processing_with_delay if it's set" do
      dummy.image.post_processing_with_delay = true
      dummy.image.delay_processing?.should be_false
    end
  end

  describe "processing?" do
    it "delegates to the dummy instance" do
      dummy.expects(:image_processing?)
      dummy.image.processing?
    end
  end

  describe "process_delayed!" do
    it "sets job_is_processing to true" do
      dummy.image.expects(:job_is_processing=).with(true).once
      dummy.image.expects(:job_is_processing=).with(false).once
      dummy.image.process_delayed!
    end

    it "sets post_processing to true" do
      dummy.image.expects(:post_processing=).with(true).once
      dummy.image.process_delayed!
    end

    context "without only_process options" do
      it "calls reprocess!" do
        dummy.image.expects(:reprocess!)
        dummy.image.process_delayed!
      end
    end

    context "with only_process options" do
      before :each do
        reset_dummy(paperclip: { only_process: [:small, :large] } )
      end

      it "calls reprocess! with options" do
        dummy.image.expects(:reprocess!).with(:small, :large)
        dummy.image.process_delayed!
      end
    end
  end

  describe "#processing_image_url" do
    context "no url" do
      it "returns nil" do
        dummy.image.processing_image_url.should be_nil
      end
    end

    context "static url" do
      before :each do
        reset_dummy(:processing_image_url => "/foo/bar.jpg")
      end

      it "returns given url" do
        dummy.image.processing_image_url.should == "/foo/bar.jpg"
      end
    end

    context "proc" do
      before :each do
        reset_dummy(:processing_image_url => proc { "Hello/World" } )
      end

      it "returns evaluates proc" do
        dummy.image.processing_image_url.should == "Hello/World"
      end
    end
  end

  describe "#after_flush_writes_with_processing" do
    it "updates the column to false" do
      dummy.update_attribute(:image_processing, true)

      dummy.image.after_flush_writes_with_processing

      dummy.image_processing.should be_false
    end
  end

  describe "#save_with_prepare_enqueueing" do
    context "delay processing and it was dirty" do
      before :each do
        dummy.image.stubs(:delay_processing?).returns true
        dummy.image.instance_variable_set(:@dirty, true)
      end

      it "prepares the enqueing" do
        dummy.expects(:prepare_enqueueing_for).with(:image)
        dummy.image.save_with_prepare_enqueueing
      end
    end

    context "without dirty or delay_processing" do
      it "does not prepare_enqueueing" do
        dummy.expects(:prepare_enqueueing_for).with(:image).never
        dummy.image.save_with_prepare_enqueueing
      end
    end
  end

  describe "#reprocess_without_delay!" do
    it "sets post post_processing_with_delay and reprocesses with given args" do
      dummy.image.expects(:reprocess!).with(:small)
      dummy.image.reprocess_without_delay!(:small)
      dummy.image.instance_variable_get(:@post_processing_with_delay).should == true
    end
  end
end