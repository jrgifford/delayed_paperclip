require 'spec_helper'

describe DelayedPaperclip::UrlGenerator do
  before :all do
    DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
    reset_dummy
  end

  let(:dummy) { Dummy.create }
  let(:attachment) { dummy.image }


  describe "#most_appropriate_url_with_processed" do
    context "without delayed_default_url" do
      subject { Paperclip::UrlGenerator.new(attachment, {url: "/blah/url.jpg"})}

      before :each do
        subject.stubs(:delayed_default_url?).returns false
      end

      context "with original file name" do
        before :each do
          attachment.stubs(:original_filename).returns "blah"
        end

        it "returns options url" do
          subject.most_appropriate_url_with_processed.should == "/blah/url.jpg"
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
            subject.most_appropriate_url_with_processed
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
              subject.most_appropriate_url_with_processed
            end
          end

          context "with processing_image_url" do
            before :each do
              attachment.stubs(:processing_image_url).returns "/processing/image.jpg"\
            end

            context "and is processing" do
              before :each do
                attachment.stubs(:processing?).returns true
              end

              it "gets processing url" do
                subject.most_appropriate_url_with_processed.should == "/processing/image.jpg"
              end
            end

            context "and is not processing" do
              it "gets default url" do
                subject.expects(:default_url)
                subject.most_appropriate_url_with_processed
              end
            end
          end
        end
      end
    end
  end

  describe "#timestamp_possible_with_processed?" do
    subject { Paperclip::UrlGenerator.new(attachment, {})}

    context "with delayed_default_url" do
      before :each do
        subject.stubs(:delayed_default_url?).returns true
      end

      it "is false" do
        subject.timestamp_possible_with_processed?.should be_false
      end
    end

    context "without delayed_default_url" do
      before :each do
        subject.stubs(:delayed_default_url?).returns false
      end

      it "goes up the chain" do
        subject.expects(:timestamp_possible_without_processed?)
        subject.timestamp_possible_with_processed?
      end
    end
  end

  describe "#delayed_default_url?" do
    subject { Paperclip::UrlGenerator.new(attachment, {})}

    before :each do
      attachment.stubs(:job_is_processing).returns false
      attachment.stubs(:dirty?).returns false
      attachment.delayed_options[:url_with_processing] = true
      attachment.instance.stubs(:respond_to?).with(:image_processing?).returns true
      attachment.stubs(:processing?).returns true
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
  end
end