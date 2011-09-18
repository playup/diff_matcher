RUBY_1_9 = (RUBY_VERSION =~ /^1\.9/)
if RUBY_1_9
  require 'simplecov'
  SimpleCov.start
end
require "diff_matcher"
