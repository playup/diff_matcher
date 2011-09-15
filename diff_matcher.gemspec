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

  s.summary       = %q{Generates a diff by matching against expected values, classes, regexes and/or procs.}
  s.description   = <<EOF
DiffMatcher performs recursive matches on values contained in hashes, arrays and combinations thereof.

Values in a containing object match when:

    - actual == expected
    - actual.is_a? expected  # when expected is a class
    - expected.match actual  # when expected is a regexp
    - expected.call actual   # when expected is a proc
EOF

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
end
