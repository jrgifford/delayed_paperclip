require 'spec_helper'

describe DelayedPaperclip::UrlGenerator do
  before :each do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
    reset_dummy(dummy_options)
  end

  let(:dummy) { Dummy.create }
  let(:attachment) { dummy.image }
  let(:dummy_options) { {} }

  describe "for" do
    before do
      attachment.stubs(:original_filename).returns "12k.png"
    end

    context "with split processing" do
      # everything in this hash is passed to delayed_paperclip, except for the
      # paperclip stuff
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

      context "processing" do
        before do
          attachment.stubs(:processing?).returns true
        end

        it "returns the default_url when the style is still being processed" do
          expect(attachment.url(:background)).to eql "/images/background/missing.png"
        end

        it "returns the attachment url when the style is not set for background processing" do
          expect(attachment.url(:online)).to eql "/system/dummies/images/000/000/001/online/12k.png"
        end
      end

      context "not processing" do
        before do
          attachment.stubs(:processing?).returns false
        end

        it "returns the attachment url even when the style is set for background processing" do
          expect(attachment.url(:background)).to eql "/system/dummies/images/000/000/001/background/12k.png"
        end

        it "returns the generated url when the style is not set for background processing" do
          expect(attachment.url(:online)).to eql "/system/dummies/images/000/000/001/online/12k.png"
        end
      end
    end
  end

  describe "#most_appropriate_url" do
    context "without delayed_default_url" do
      subject { DelayedPaperclip::UrlGenerator.new(attachment, {url: "/blah/url.jpg"})}

      before :each do
        subject.stubs(:delayed_default_url?).returns false
      end
      context "with original file name" do
        before :each do
          attachment.stubs(:original_filename).returns "blah"
        end

        it "returns options url" do
          subject.most_appropriate_url.should == "/blah/url.jpg"
        end
      end

      context "without original_filename" do
        before :each do
          attachment.stubs(:original_filename).returns nil
        end

        context "without delayed_options" do
          before :each do
            attachment.stubs(:delayed_options).returns nil
          end

          it "gets default url" do
            subject.expects(:default_url)
            subject.most_appropriate_url
          end
        end

        context "with delayed_options" do
          before :each do
            attachment.stubs(:delayed_options).returns "something"
          end

          context "without processing_image_url" do
            before :each do
              attachment.stubs(:processing_image_url).returns nil
            end

            it "gets default url" do
              subject.expects(:default_url)
              subject.most_appropriate_url
            end
          end

          context "with processing_image_url" do
            before :each do
              attachment.stubs(:processing_image_url).returns "/processing/image.jpg"
            end

            context "and is processing" do
              before :each do
                attachment.stubs(:processing?).returns true
              end

              it "gets processing url" do
                subject.most_appropriate_url.should == "/processing/image.jpg"
              end
            end

            context "and is not processing" do
              it "gets default url" do
                subject.expects(:default_url)
                subject.most_appropriate_url
              end
            end
          end
        end
      end
    end
  end

  describe "#timestamp_possible?" do
    subject { DelayedPaperclip::UrlGenerator.new(attachment, {})}

    context "with delayed_default_url" do
      before :each do
        subject.stubs(:delayed_default_url?).returns true
      end

      it "is false" do
        subject.timestamp_possible?.should be_false
      end
    end

    context "without delayed_default_url" do
      before :each do
        subject.stubs(:delayed_default_url?).returns false
      end

      it "goes up the chain" do
        subject.expects(:timestamp_possible_without_processed?)
        subject.timestamp_possible?
      end
    end
  end

  describe "#delayed_default_url?" do
    subject { DelayedPaperclip::UrlGenerator.new(attachment, {})}

    before :each do
      attachment.stubs(:job_is_processing).returns false
      attachment.stubs(:dirty?).returns false
      attachment.delayed_options[:url_with_processing] = true
      attachment.instance.stubs(:respond_to?).with(:image_processing?).returns true
      attachment.stubs(:processing?).returns true
      attachment.stubs(:processing_style?).with(anything).returns true
    end

    it "has all false, delayed_default_url returns true" do
      subject.delayed_default_url?.should be_true
    end

    context "job is processing" do
      before :each do
        attachment.stubs(:job_is_processing).returns true
      end

      it "returns true" do
        subject.delayed_default_url?.should be_false
      end
    end

    context "attachment is dirty" do
      before :each do
        attachment.stubs(:dirty?).returns true
      end

      it "returns true" do
        subject.delayed_default_url?.should be_false
      end
    end

    context "attachment has delayed_options without url_with_processing" do
      before :each do
        attachment.delayed_options[:url_with_processing] = false
      end

      it "returns true" do
        subject.delayed_default_url?.should be_false
      end
    end

    context "attachment does not responds to name_processing and is not processing" do
      before :each do
        attachment.instance.stubs(:respond_to?).with(:image_processing?).returns false
        attachment.stubs(:processing?).returns false
      end

      it "returns true" do
        subject.delayed_default_url?.should be_false
      end
    end

    context "style is provided and is being processed" do
      let(:style) { :main }
      before :each do
        attachment.stubs(:processing_style?).with(style).returns(true)
      end

      specify { expect(subject.delayed_default_url?(style)).to be }
    end
  end
end
