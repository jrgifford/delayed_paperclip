require 'spec_helper'

describe DelayedPaperclip::Attachment do

  before :each do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
    reset_dummy(dummy_options)
  end

  let(:dummy_options) { {} }
  let(:dummy) { Dummy.create }

  describe "#delayed_options" do

    it "returns the specific options for delayed paperclip" do
      dummy.image.delayed_options.should == {
        :priority => 0,
        :only_process => [],
        :url_with_processing => true,
        :processing_image_url => nil,
        :queue => nil
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

    context "without a processing column" do
      let(:dummy_options) { { with_processed: false } }

      it "returns false" do
        expect(dummy.image.processing?).to be_false
      end
    end
  end

  describe "processing_stye?" do
    let(:style) { :background }
    let(:processing_style?) { dummy.image.processing_style?(style) }

    context "without a processing column" do
      let(:dummy_options) { { with_processed: true, process_column: false } }

      specify { expect(processing_style?).to be_false }
    end

    context "with a processing column" do
      context "when not processing" do
        before { dummy.image_processing = false }

        specify { expect(processing_style?).to be_false }
      end

      context "when processing" do
        before { dummy.image_processing = true }

        context "when not split processing" do
          specify { expect(processing_style?).to be_true }
        end

        context "when split processing" do
          let(:dummy_options) { {
            paperclip: {
              styles: {
                online: "400x400x",
                background: "600x600x"
              },
              only_process: [:online]
            },

            delayed_paperclip: {
              only_process: [:background]
            }
          }}

          specify { expect(processing_style?).to be }
        end
      end
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
    context "when corresponding updated_at column not also updated" do
      it "does not update the column" do
        dummy.update_attributes(image_processing: true)

        dummy.image.after_flush_writes_with_processing

        dummy.image_processing.should_not be_false
      end
    end

    context "when corresponding updated_at column also updated" do
      it "updates the column to false" do
        dummy.update_attributes(image_processing: true, image_updated_at: Time.now)

        dummy.image.after_flush_writes_with_processing

        dummy.image_processing.should be_false
      end
    end

    context "on a model with multiple attachments" do
      before :each do
        reset_dummy(multiple_attachments: true)
      end

      it "doesn't update all attachments as done when only one is" do
        dummy.update_attributes(image_processing: true, image_updated_at: Time.now, alt_image_processing: true)

        dummy.image.after_flush_writes_with_processing

        dummy.alt_image_processing.should be_true
      end
    end

    it "still flushes temp files" do
      dummy.image = File.open("#{ROOT}/spec/fixtures/12k.png")
      paths = dummy.image.queued_for_write.values.map(&:path)
      dummy.image.after_flush_writes_with_processing
      paths.none?{ |path| File.exists?(path) }.should be_true
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
