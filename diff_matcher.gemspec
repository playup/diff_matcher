# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "diff_matcher/version"

Gem::Specification.new do |s|

  s.name          = "diff_matcher"
  s.version       = DiffMatcher::VERSION.dup
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Playup"]
  s.email         = "chris@playup.com"
  s.homepage      = "http://github.com/playup/diff_matcher"

  s.summary       = %q{Generates a diff by matching against user-defined matchers written in ruby.}
  s.description   = <<EOF
DiffMatcher matches input data (eg. from a JSON API) against values,
ranges, classes, regexes, procs, custom matchers and/or easily composed,
nested combinations thereof to produce an easy to read diff string.
EOF

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
end
