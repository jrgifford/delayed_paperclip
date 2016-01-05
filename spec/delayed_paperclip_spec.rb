require 'spec_helper'
require 'resque'

describe DelayedPaperclip do
  before :each do
    reset_dummy
  end

  context "with Resque adapter" do
    before :each do
      DelayedPaperclip.options[:background_job_class] = DelayedPaperclip::Jobs::Resque
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
  end

  describe ".process_job" do
    let(:dummy) { Dummy.create! }

    it "finds dummy and calls #process_delayed!" do
      dummy_stub = stub
      dummy_stub.expects(:where).with(id: dummy.id).returns([dummy])
      Dummy.expects(:unscoped).returns(dummy_stub)
      dummy.image.expects(:process_delayed!)
      DelayedPaperclip.process_job("Dummy", dummy.id, :image)
    end

    it "doesn't find dummy and it doesn't raise any exceptions" do
      dummy_stub = stub
      dummy_stub.expects(:where).with(id: dummy.id).returns([])
      Dummy.expects(:unscoped).returns(dummy_stub)
      expect do
        DelayedPaperclip.process_job("Dummy", dummy.id, :image)
      end.not_to raise_exception
    end
  end

  describe "paperclip definitions" do
    before :each do
      DelayedPaperclip.options[:queue] = "bar"
      reset_dummy :paperclip => { styles: { thumbnail: "25x25"} }
    end

    after :each do
      DelayedPaperclip.options[:queue] = nil
      reset_dummy
    end

    it "returns paperclip options regardless of version" do
      Dummy.paperclip_definitions.should ==  {:image =>   { :styles => { :thumbnail => "25x25" },
                                              :delayed => { :priority => 0,
                                                            :only_process => [],
                                                            :url_with_processing => true,
                                                            :processing_image_url => nil,
                                                            :queue => "bar"}
                                                          }
                                              }
    end
  end
end
