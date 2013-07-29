require 'spec_helper'
require 'resque'

describe DelayedPaperclip do
  before :all do
    reset_dummy
  end

  describe ".options" do
    it ".options returns basic options" do
      DelayedPaperclip.options.should == {:background_job_class => DelayedPaperclip::Jobs::Resque,
                                          :url_with_processing => true,
                                          :processing_image_url => nil}
    end
  end

  describe ".processor" do
    it ".processor returns processor" do
      DelayedPaperclip.processor.should == DelayedPaperclip::Jobs::Resque
    end
  end

  describe ".enqueue" do
    it "delegates to processor" do
      DelayedPaperclip::Jobs::Resque.expects(:enqueue_delayed_paperclip).with("Dummy", 1, :image)
      DelayedPaperclip.enqueue("Dummy", 1, :image)
    end
  end

  describe ".process_job" do
    let(:dummy) { Dummy.create! }

    it "finds dummy and calls #process_delayed!" do
      Dummy.expects(:find).with(dummy.id).returns(dummy)
      dummy.image.expects(:process_delayed!)
      DelayedPaperclip.process_job("Dummy", dummy.id, :image)
    end
  end

  describe "paperclip definitions" do
    before :all do
      reset_dummy :paperclip => { styles: { thumbnail: "25x25"} }
    end

    it "returns paperclip options regardless of version" do
      Dummy.paperclip_definitions.should ==  {:image =>   { :styles => { :thumbnail => "25x25" },
                                              :delayed => { :priority => 0,
                                                            :only_process => nil,
                                                            :url_with_processing => true,
                                                            :processing_image_url => nil}
                                                          }
                                              }
    end

  end
end