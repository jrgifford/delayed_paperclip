require 'spec_helper'

describe DelayedPaperclip::Attachment do
  before :each do
    reset_dummy(dummy_options)
  end

  let(:dummy_options) { {} }
  let(:dummy) { Dummy.create }

  describe "#delayed_options" do
    it "returns the specific options for delayed paperclip" do
      expect(dummy.image.delayed_options).to eq({
        :priority => 0,
        :only_process => [],
        :url_with_processing => true,
        :processing_image_url => nil,
        :queue => "paperclip",
        :post_processing_callback => nil,
        :post_update_callback => nil,
        :pre_processing_callback => nil
      })
    end
  end

  describe "#post_processing_with_delay" do
    it "is true if delay_processing? is false" do
      dummy.image.stubs(:delay_processing?).returns false
      dummy.image.post_processing.should be_truthy
    end

    it "is false if delay_processing? is true" do
      dummy.image.stubs(:delay_processing?).returns true
      dummy.image.post_processing.should be_falsey
    end

    context "on a non-delayed image" do
      let(:dummy_options) { { with_processed: false } }

      it "is false if delay_processing? is true" do
        dummy.image.stubs(:delay_processing?).returns true
        dummy.image.post_processing.should be_falsey
      end
    end
  end

  describe "#delay_processing?" do
    it "returns delayed_options existence if post_processing is nil" do
      dummy.image.post_processing = nil
      dummy.image.delay_processing?.should be_truthy
    end

    it "returns inverse of post_processing if it's set" do
      dummy.image.post_processing = true
      dummy.image.delay_processing?.should be_falsey
    end
  end

  describe "#processing?" do
    it "delegates to the dummy instance" do
      dummy.expects(:image_processing?)
      dummy.image.processing?
    end

    context "without a processing column" do
      let(:dummy_options) { { with_processed: false } }

      it "returns false" do
        expect(dummy.image.processing?).to be_falsey
      end
    end
  end

  describe "#processing_style?" do
    let(:style) { :background }
    let(:processing_style?) { dummy.image.processing_style?(style) }

    context "without a processing column" do
      let(:dummy_options) { { with_processed: true, process_column: false } }

      specify { expect(processing_style?).to be_falsey }
    end

    context "with a processing column" do
      context "when not processing" do
        before { dummy.image_processing = false }

        specify { expect(processing_style?).to be_falsey }
      end

      context "when processing" do
        before { dummy.image_processing = true }

        context "when not split processing" do
          specify { expect(processing_style?).to be_truthy }
        end

        context "when split processing" do
          context "when delayed :only_process is an Array" do
            let(:dummy_options) { {
              paperclip: {
                styles: {
                  online: "400x400x",
                  background: "600x600x"
                },
                only_process: [:online]
              },

              only_process: [:background]
            }}

            specify { expect(processing_style?).to be }
          end

          context "when delayed :only_process is callable" do
            let(:dummy_options) { {
              paperclip: {
                styles: {
                  online: "400x400x",
                  background: "600x600x"
                },
                only_process: [:online]
              },

              only_process: lambda { |a| [:background] }
            }}

            specify { expect(processing_style?).to be }
          end
        end
      end
    end
  end

  describe "#delayed_only_process" do
    context "without only_process options" do
      it "returns []" do
        expect(dummy.image.delayed_only_process).to eq []
      end
    end

    context "with only_process options" do
      before :each do
        reset_dummy(paperclip: { only_process: [:small, :large] } )
      end

      it "returns [:small, :large]" do
        expect(dummy.image.delayed_only_process).to eq [:small, :large]
      end
    end

    context "with only_process set with callable" do
      before :each do
        reset_dummy(paperclip: { only_process: lambda { |a| [:small, :large] } } )
      end

      # Enable when https://github.com/thoughtbot/paperclip/pull/2289 is resolved
      xit "returns [:small, :large]" do
        expect(dummy.image.delayed_only_process).to eq [:small, :large]
      end
    end
  end

  describe "#process_delayed!" do
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

    context "with only_process set with callable" do
      before :each do
        reset_dummy(paperclip: { only_process: lambda { |a| [:small, :large] } } )
      end

      # Enable when https://github.com/thoughtbot/paperclip/pull/2289 is resolved
      xit "calls reprocess! with options" do
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

  describe "#update_processing_column" do
    it "updates the column to false" do
      dummy.update_attribute(:image_processing, true)

      dummy.image.send(:update_processing_column)

      dummy.image_processing.should be_falsey
    end
  end

  describe "#save" do
    context "delay processing and it was dirty" do
      before :each do
        dummy.image.stubs(:delay_processing?).returns true
        dummy.image.instance_variable_set(:@dirty, true)
      end

      it "prepares the enqueing" do
        dummy.expects(:prepare_enqueueing_for).with(:image)
        dummy.image.save
      end
    end

    context "without dirty or delay_processing" do
      it "does not prepare_enqueueing" do
        dummy.expects(:prepare_enqueueing_for).with(:image).never
        dummy.image.save
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

  describe "#split_processing?" do
    let(:split_processing?) { dummy.image.split_processing? }

    let(:paperclip_styles) { {
      online: "400x400x",
      background: "600x600x"
    } }

    context ":only_process option is set on attachment" do
      let(:dummy_options) { {
        paperclip: {
          styles: paperclip_styles,
          only_process: [:online]
        },

        only_process: delayed_only_process
      }}

      context "processing different styles in background" do
        context "when delayed :only_process is an Array" do
          let(:delayed_only_process) { [:background] }

          specify { expect(split_processing?).to be true }
        end

        context "when delayed :only_process is callable" do
          let(:delayed_only_process) { lambda { |a| [:background] } }

          specify { expect(split_processing?).to be true }
        end
      end

      context "processing same styles in background" do
        context "when delayed :only_process is an Array" do
          let(:delayed_only_process) { [:online] }

          specify { expect(split_processing?).to be false }
        end

        context "when delayed :only_process is callable" do
          let(:delayed_only_process) { lambda { |a| [:online] } }

          specify { expect(split_processing?).to be false }
        end
      end
    end

    context ":only_process option is not set on attachment" do
      let(:dummy_options) { {
        paperclip: {
          styles: paperclip_styles
        }
      }}

      specify { expect(split_processing?).to be false }
    end
  end
end
