module BaseDelayedPaperclipTest
  def setup
    super
    DelayedPaperclip.options[:url_with_processing] = true
    reset_dummy
  end

  def test_normal_paperclip_functioning
    reset_dummy :with_processed => false
    Paperclip::Attachment.any_instance.expects(:post_process)
    dummy = Dummy.new(:image => File.open("#{ROOT}/test/fixtures/12k.png"))
    assert !dummy.image.delay_processing?
    assert dummy.image.post_processing
    assert dummy.save
    assert File.exists?(dummy.image.path)
  end

  def test_normal_explicit_post_processing_with_delayed_paperclip
    reset_dummy :with_processed => true
    dummy = Dummy.new(:image => File.open("#{ROOT}/test/fixtures/12k.png"))
    dummy.image.post_processing = true
    assert !dummy.image.delay_processing?
    assert dummy.image.post_processing, "Post processing should return true"
    assert dummy.save
    assert File.exists?(dummy.image.path)
  end

  def test_delayed_paperclip_functioning
    build_dummy_table(false)
    reset_class "Dummy", :with_processed => true
    Paperclip::Attachment.any_instance.expects(:post_process).never
    dummy = Dummy.new(:image => File.open("#{ROOT}/test/fixtures/12k.png"))
    assert dummy.image.delay_processing?
    assert !dummy.image.post_processing
    assert dummy.save
    assert File.exists?(dummy.image.path), "Path #{dummy.image.path} should exist"
  end

  def test_enqueue_job_if_source_changed
    dummy = Dummy.new(:image => File.open("#{ROOT}/test/fixtures/12k.png"))
    dummy.image = File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    original_job_count = jobs_count
    dummy.save
    assert_equal original_job_count + 1, jobs_count
  end

  def test_processing_column_kept_intact
    Paperclip::Attachment.any_instance.stubs(:reprocess!).raises(StandardError.new('oops'))
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image_processing?
    process_jobs
    assert dummy.image_processing?
    assert dummy.reload.image_processing?
  end

  def test_processing_true_when_new_image_added
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    assert !dummy.image_processing?
    assert dummy.new_record?
    dummy.save!
    assert dummy.reload.image_processing?
  end

  def test_processed_true_when_delayed_jobs_completed
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
    dummy.reload
    assert !dummy.image_processing?, "Image should no longer be processing"
  end

  def test_unprocessed_image_returns_missing_url
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image.url.starts_with?("/images/original/missing.png")
    process_jobs
    dummy.reload
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_unprocess_image_returns_reprocessing_url
    reset_dummy :processing_image_url => "/images/original/processing.png"
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image.url.starts_with?("/images/original/processing.png")
    process_jobs
    dummy.reload
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_unprocessed_image_not_returning_missing_url_if_turned_of_globally
    DelayedPaperclip.options[:url_with_processing] = false
    reset_dummy :with_processed => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
    process_jobs
    dummy.reload
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_unprocessed_image_not_returning_missing_url_if_turned_of_on_instance
    reset_dummy :with_processed => false, :url_with_processing => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
    process_jobs
    dummy.reload
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_unprocessed_processing_url_when_file
    reset_dummy :with_processed => true, :processing_image_url => "processing"
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.reload.image.url.starts_with?("processing")
  end

  def test_processed_default_url_when_no_file
    reset_dummy :with_processed => true, :processing_image_url => "processing"
    dummy = Dummy.new()
    dummy.save!
    assert dummy.reload.image.url.starts_with?("/images/original/missing.png")
  end

  def test_original_url_when_no_processing_column
    reset_dummy :with_processed => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.reload.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_original_url_if_image_changed
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    dummy.image = File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    dummy.save!
    assert dummy.image.url.starts_with?("/images/original/missing.png")
    process_jobs
    assert dummy.reload.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_missing_url_if_image_hasnt_changed
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert_match(/images\/.*missing.*/, dummy.image.url)
  end

  def test_should_not_blow_up_if_dsl_unused
    reset_dummy :with_processed => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    assert dummy.image.url
  end

  def test_after_callback_is_functional
    Dummy.send(:define_method, :done_processing) { puts 'done' }
    Dummy.after_image_post_process :done_processing
    Dummy.any_instance.expects(:done_processing).once
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
  end

  def test_delayed_paperclip_functioning_with_after_update_callback
    reset_class "Dummy", :with_processed => true, :with_after_update_callback => true
    Dummy.any_instance.expects(:reprocess).once
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
  end

  def test_delayed_paperclip_functioning_with_only_process_option
    reset_class "Dummy", :with_processed => true, :only_process => [:thumbnail]
    Paperclip::Attachment.any_instance.expects(:reprocess!).with(:thumbnail)
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
  end

  def test_delayed_paperclip_functioning_with_paperclip_only_process_option
    reset_class "Dummy", :with_processed => true, :paperclip => { :only_process => [:thumbnail] }
    Paperclip::Attachment.any_instance.expects(:reprocess!).with(:thumbnail)
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
  end

  def test_delayed_paperclip_should_convert_image_formats
    reset_class "Dummy", :with_processed => true, :paperclip => { :styles => {:thumbnail => ['12x12', :jpg]} }
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
    assert dummy.reload.image.url(:thumbnail).starts_with?("/system/dummies/images/000/000/001/thumbnail/12k.jpg")
    assert File.exists?("#{RAILS_ROOT}/public/system/dummies/images/000/000/001/thumbnail/12k.jpg")
  end

  def test_delayed_paperclip_without_delay
    reset_class "Dummy", :with_processed => true, :paperclip => { :styles => {:thumbnail => ['12x12', :jpg]} }
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!

    existing_jobs_count = jobs_count
    dummy.update_attribute(:image_processing, false)
    dummy.image.reprocess_without_delay!(:thumbnail)
    Paperclip::Attachment.any_instance.expects(:reprocess!).never
    assert_equal existing_jobs_count, jobs_count
    assert_equal false, dummy.image_processing?
    assert File.exists?("#{RAILS_ROOT}/public/system/dummies/images/000/000/001/thumbnail/12k.jpg")
  end

  def test_unprocess_image_interpolates_reprocessing_url
    reset_class "Dummy", :paperclip => { :styles => {:thumbnail => '12x12'} }
    reset_dummy :processing_image_url => "/images/:style/processing.png"
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image.url.starts_with?("/images/original/processing.png")
    assert dummy.image.url(:thumbnail).starts_with?("/images/thumbnail/processing.png")
    process_jobs
    dummy.reload
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

  def test_unprocess_image_accepts_proc_for_reprocessing_url
    reset_class "Dummy", :paperclip => { :styles => {:thumbnail => '12x12'} }
    reset_dummy :processing_image_url => lambda { |attachment| attachment.instance.reprocessing_url }
    Dummy.send(:define_method, :reprocessing_url) { 'done' }
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert dummy.image.url.starts_with?("done")
    process_jobs
    dummy.reload
    assert dummy.image.url.starts_with?("/system/dummies/images/000/000/001/original/12k.png")
  end

end
