require 'rubygems'
require 'bundler/setup'

require 'appraisal'

require 'rake'
require 'rake/testtask'

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')

desc 'Default: run unit tests.'
task :default => [:clean, 'appraisal:install', :all]

desc 'Test the delayed paperclip plugin under all supported Rails versions.'
task :all do |t|
  exec('rake appraisal test')
end

desc 'Clean up files.'
task :clean do |t|
  FileUtils.rm_rf "doc"
  FileUtils.rm_rf "tmp"
  FileUtils.rm_rf "pkg"
  FileUtils.rm_rf "public"
  FileUtils.rm    "test/debug.log" rescue nil
  FileUtils.rm    "test/paperclip.db" rescue nil
  Dir.glob("paperclip-*.gem").each{|f| FileUtils.rm f }
end

desc 'Test the paperclip plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib:test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

