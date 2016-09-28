require 'spec_helper'

describe DelayedPaperclip::ClassMethods do
  before :each do
    reset_dummy(with_processed: false)
  end

  describe ".process_in_background" do
    it "is empty to start" do
      Dummy.paperclip_definitions.should == { :image => {} }
    end

    it "adds basics to paperclip_definitions" do
      Dummy.process_in_background(:image)
      Dummy.paperclip_definitions.should == { :image => {
        :delayed => {
          :priority => 0,
          :only_process => [],
          :url_with_processing => true,
          :processing_image_url => nil,
          :queue => "paperclip",
          :post_processing_callback => nil,
          :post_update_callback => nil,
          :pre_processing_callback => nil }
        }
      }
    end

    it "allows to set queue name" do
      Dummy.process_in_background(:image, :queue => "custom")
      expect(Dummy.paperclip_definitions).to eq({ :image => {
        :delayed => {
          :priority => 0,
          :only_process => [],
          :url_with_processing => true,
          :processing_image_url => nil,
          :queue => "custom",
          :post_processing_callback => nil,
          :post_update_callback => nil,
          :pre_processing_callback => nil }
        }
      })
    end

    context "with processing_image_url" do
      before :each do
        Dummy.process_in_background(:image, processing_image_url: "/processing/url")
      end

      it "incorporates processing url" do
        Dummy.paperclip_definitions.should == { :image => {
          :delayed => {
            :priority => 0,
            :only_process => [],
            :url_with_processing => true,
            :processing_image_url => "/processing/url",
            :queue => "paperclip",
            :post_processing_callback => nil,
            :post_update_callback => nil,
            :pre_processing_callback => nil }
          }
        }
      end
    end

    context "inherits only_process options" do
      before :each do
        reset_class("Dummy", paperclip: { only_process: [:small, :large] } )
        Dummy.process_in_background(:image)
      end

      it "incorporates processing url" do
        Dummy.paperclip_definitions.should == { :image => {
          :only_process => [:small, :large],
          :delayed => {
            :priority => 0,
            :only_process => [:small, :large],
            :url_with_processing => true,
            :processing_image_url => nil,
            :queue => "paperclip",
            :post_processing_callback => nil,
            :post_update_callback => nil,
            :pre_processing_callback => nil }
          }
        }
      end
    end

    context "sets callback" do
      context "commit" do
        it "sets after_commit callback" do
          Dummy.expects(:after_commit).with(:enqueue_delayed_processing)
          Dummy.process_in_background(:image)
        end
      end

      context "save" do
        it "sets after_save callback" do
          Dummy.stubs(:respond_to?).with(:attachment_definitions).returns(true)
          Dummy.stubs(:respond_to?).with(:after_commit).returns(false)
          Dummy.expects(:after_save).with(:enqueue_delayed_processing)
          Dummy.process_in_background(:image)
        end
      end
    end
  end
end
