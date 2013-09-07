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

  def test_normal_explisit_post_processing_with_delayed_paperclip
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
    assert_equal "/images/original/missing.png", dummy.image.url(:original, :timestamp => false)
    process_jobs
    dummy.reload
    assert_match /\/system\/images\/1\/original\/12k.png/, dummy.image.url
  end

  def test_unprocessed_image_not_returning_missing_url_if_turrned_of_globally
    DelayedPaperclip.options[:url_with_processing] = false
    reset_dummy :with_processed => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert_match /\/system\/images\/1\/original\/12k.png/, dummy.image.url
    process_jobs
    dummy.reload
    assert_match /\/system\/images\/1\/original\/12k.png/, dummy.image.url
  end

  def test_unprocessed_image_not_returning_missing_url_if_turrned_of_on_instance
    reset_dummy :with_processed => false, :url_with_processing => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert_match(/\/system\/images\/1\/original\/12k.png/, dummy.image.url)
    process_jobs
    dummy.reload
    assert_match(/\/system\/images\/1\/original\/12k.png/, dummy.image.url)
  end

  def test_original_url_when_no_processing_column
    reset_dummy :with_processed => false
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    assert_match(/\/system\/images\/1\/original\/12k.png/, dummy.image.url)
  end

  def test_original_url_if_image_changed
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    dummy.image = File.open("#{RAILS_ROOT}/test/fixtures/12k.png")
    dummy.save!
    assert_equal '/images/original/missing.png', dummy.image.url(:original, :timestamp => false)
    process_jobs
    assert_match(/system\/images\/.*original.*/, dummy.reload.image.url)
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
    Dummy.any_instance.expects(:done_processing)
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
  end

  def test_delayed_paperclip_functioning_with_after_update_callback
    reset_class "Dummy", :with_processed => true, :with_after_update_callback => true
    Dummy.any_instance.expects(:reprocess)
    dummy = Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
    dummy.save!
    process_jobs
    dummy.update_attributes(:name => "hi")
  end

  def test_only_process_is_passed_to_paperclip
    reset_dummy :paperclip => { 
                  :styles => { :foo => "12x12", :bar => "10x10" } 
                }, 
                :only_process => [:foo]

    assert Dummy.attachment_definitions[:image].has_key? :only_process
    assert_equal [:foo], Dummy.attachment_definitions[:image][:only_process]
  end
end
