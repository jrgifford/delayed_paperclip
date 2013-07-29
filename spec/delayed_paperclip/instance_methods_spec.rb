require 'spec_helper'

describe DelayedPaperclip::InstanceMethods do

  before :all do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
    reset_dummy
  end

  let(:dummy) { Dummy.create }

  describe "#enqueue_delayed_processing" do

    it "marks enqueue_delayed_processing" do
      dummy.expects(:mark_enqueue_delayed_processing)
      dummy.enqueue_delayed_processing
    end

    it "enqueues post processing for all enqueued" do
      dummy.instance_variable_set(:@_enqued_for_processing, ['image'])
      dummy.expects(:enqueue_post_processing_for).with('image')
      dummy.enqueue_delayed_processing
    end

    it "clears instance variables" do
      dummy.instance_variable_set(:@_enqued_for_processing, ['foo'])
      dummy.instance_variable_set(:@_enqued_for_processing_with_processing, ['image'])
      dummy.enqueue_delayed_processing
      dummy.instance_variable_get(:@_enqued_for_processing).should == []
      dummy.instance_variable_get(:@_enqued_for_processing_with_processing).should == []
    end

  end

  describe "#mark_enqueue_delayed_processing" do
    it "updates columns of _processing" do
      dummy.image_processing.should be_false
      dummy.instance_variable_set(:@_enqued_for_processing_with_processing, ['image'])
      dummy.mark_enqueue_delayed_processing
      dummy.reload.image_processing.should be_true
    end

    it "does nothing if instance variable not set" do
      dummy.image_processing.should be_false
      dummy.mark_enqueue_delayed_processing
      dummy.reload.image_processing.should be_false
    end
  end

  describe "#enqueue_post_processing_for" do
    it "enqueues the instance and image" do
      DelayedPaperclip.expects(:enqueue).with("Dummy", dummy.id, :image)
      dummy.enqueue_post_processing_for("image")
    end
  end

  describe "#prepare_enqueueing_for" do

    it "updates processing column to true" do
      pending
      # TODO: Why would it be writing the attribute here as well as in mark_enqueue_delayed_processing
      dummy.image_processing.should be_false
      dummy.expects(:write_attribute).with("image_processing", true)
      dummy.prepare_enqueueing_for("image")
      dummy.image_processing.should be_true
    end

    it "sets instance variables for column updating" do
      dummy.prepare_enqueueing_for("image")
      dummy.instance_variable_get(:@_enqued_for_processing_with_processing).should == ["image"]
    end

    it "sets instance variables for processing" do
      dummy.prepare_enqueueing_for("image")
      dummy.instance_variable_get(:@_enqued_for_processing).should == ["image"]
    end
  end


end
