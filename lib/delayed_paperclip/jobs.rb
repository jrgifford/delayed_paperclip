module DelayedPaperclip
  module Jobs
    autoload :DelayedJob, 'delayed_paperclip/jobs/delayed_job'
    autoload :Resque,     'delayed_paperclip/jobs/resque'
    autoload :Sidekiq,    'delayed_paperclip/jobs/sidekiq'
  end
end
