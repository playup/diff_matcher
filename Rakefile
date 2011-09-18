RUBY_1_9 = (RUBY_VERSION =~ /^1\.9/)
if RUBY_1_9
  require 'bundler'
  Bundler::GemHelper.install_tasks
end

require "rspec/core/rake_task"

task "default" => "spec"

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = ["--colour", "--format", "nested"]
end
