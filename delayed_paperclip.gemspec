$:.push File.expand_path("../lib", __FILE__)
require "delayed_paperclip/version"

Gem::Specification.new do |s|
  s.name        = %q{delayed_paperclip}
  s.version     = DelayedPaperclip::VERSION

  s.authors     = ["Jesse Storimer", "Bert Goethals", "James Gifford", "Scott Carleton"]
  s.summary     = %q{Process your Paperclip attachments in the background.}
  s.description = %q{Process your Paperclip attachments in the background with DelayedJob, Resque, Sidekiq or your own processor.}
  s.email       = %w{james@jamesrgifford.com scott@artsicle.com}
  s.homepage    = %q{http://github.com/jrgifford/delayed_paperclip}

  s.add_dependency 'paperclip', [">= 3.3"]

  s.add_development_dependency 'mocha'
  s.add_development_dependency "rspec"
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'delayed_job'
  s.add_development_dependency 'delayed_job_active_record'
  s.add_development_dependency 'resque'
  s.add_development_dependency 'sidekiq'
  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'railties'
  s.add_development_dependency 'queue_classic'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
end

