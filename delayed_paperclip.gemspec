
include_files = ["README*", "LICENSE", "Rakefile", "init.rb", "{lib,tasks,test,rails,generators,shoulda_macros}/**/*"].map do |glob|
  Dir[glob]
end.flatten
exclude_files = ["**/*.rbc", "test/s3.yml", "test/debug.log", "test/paperclip.db", "test/doc", "test/doc/*", "test/pkg", "test/pkg/*", "test/tmp", "test/tmp/*"].map do |glob|
  Dir[glob]
end.flatten

spec = Gem::Specification.new do |s|
  s.name        = %q{delayed_paperclip}
  s.version     = "2.6.0.0"

  s.authors     = ["Jesse Storimer", "Bert Goethals", "James Gifford"]
  s.summary     = %q{Process your Paperclip attachments in the background.}
  s.description = %q{Process your Paperclip attachments in the background with delayed_job, Resque or your own processor.}
  s.email       = %q{james@jamesrgifford.com}
  s.homepage    = %q{http://github.com/jrgifford/delayed_paperclip}

  s.files             = include_files - exclude_files

  s.test_files        = Dir["test/**/*,rb"] + Dir['test/features/*']

  s.add_dependency 'paperclip', [">= 3.3.0"]

  s.add_development_dependency 'mocha'
  s.add_development_dependency "rspec"
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'delayed_job'
  s.add_development_dependency 'resque'
  s.add_development_dependency 'sidekiq'
end

