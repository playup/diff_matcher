DiffMatcher
===

[![build status](http://travis-ci.org/playup/diff_matcher.png)](http://travis-ci.org/playup/diff_matcher)
[![still maintained](http://stillmaintained.com/playupchris/diff_matcher.png)](http://stillmaintained.com/playupchris/diff_matcher)

Generates a diff by matching against expected values, classes, regexes and/or procs.

DiffMatcher performs recursive matches on values contained in hashes, arrays and combinations thereof.

Values in a containing object match when:

``` ruby
actual.is_a? expected  # when expected is a class
expected.match actual  # when expected is a regexp
expected.call actual   # when expected is a proc
actual == expected     # when expected is anything else
```

Example:

``` ruby
puts DiffMatcher::difference(
  { :a=>{ :a1=>11          }, :b=>[ 21, 22 ], :c=>/\d/, :d=>Fixnum, :e=>lambda { |x| (4..6).include? x } },
  { :a=>{ :a1=>10, :a2=>12 }, :b=>[ 21     ], :c=>'3' , :d=>4     , :e=>5                                },
  :color_scheme=>:white_background
)
```

![example output](https://raw.github.com/playup/diff_matcher/master/doc/diff_matcher.gif)


Installation
---

    gem install diff_matcher


Usage
---

``` ruby
require 'diff_matcher'

DiffMatcher::difference(actual, expected, opts={})
```

When `expected` != `actual`

``` ruby
puts DiffMatcher::difference(1, 2)
# => - 1+ 2
# => Where, - 1 missing, + 1 additional
```

When `expected` == `actual`

``` ruby
p DiffMatcher::difference(1, 1)
# => nil
```

When `actual` is an instance of the `expected`

``` ruby
p DiffMatcher::difference(String, '1')
# => nil
```

When `actual` is a string that matches the `expected` regex

``` ruby
p DiffMatcher::difference(/[a-z]/, "a")
# => nil
```

When `actual` is passed to an `expected` proc and it returns true

``` ruby
is_boolean = lambda { |x| [FalseClass, TrueClass].include? x.class }
p DiffMatcher::difference(is_boolean, true)
# => nil
```

When `actual` is missing one of the `expected` values

``` ruby
puts DiffMatcher::difference([1, 2], [1])
# => [
# =>   1
# => - 2
# => ]
# => Where, - 1 missing
```

When `actual` has additional values to the `expected`

``` ruby
puts DiffMatcher::difference([1], [1, 2])
# => [
# =>   1
# => + 2
# => ]
# => Where, + 1 additional
```


When `expected` is a `Hash` with optional keys use a `Matcher`.

``` ruby
puts DiffMatcher::difference(
  DiffMatcher::Matcher.new({:name=>String, :age=>Fixnum}, :optional_keys=>[:age]),
  {:name=>0}
)
{
  :name=>- String+ 0
}
Where, - 1 missing, + 1 additional
```


When `expected` can take multiple forms use some `Matcher`s `||`ed together.

``` ruby
puts DiffMatcher::difference(DiffMatcher::Matcher.new(Fixnum) || DiffMatcher.new(Float), "3")
- Float+ "3"
Where, - 1 missing, + 1 additional
```
(NB. `DiffMatcher::Matcher[Fixnum, Float]` can be used as a shortcut for 
     `DiffMatcher::Matcher.new(Fixnum) || DiffMatcher.new(Float)`
)


When `actual` is an array of *unknown* size use an `AllMatcher` to match
against *all* the elements in the array.

``` ruby
puts DiffMatcher::difference(DiffMatcher::AllMatcher.new(Fixnum), [1, 2, "3"])
[
  : 1,
  : 2,
  - Fixnum+ "3"
]
Where, - 1 missing, + 1 additional, : 2 match_class
```


When `actual` is an array with a *limited* size use an `AllMatcher` to match
against *all* the elements in the array adhering to the limits of `:min`
and or `:max` or `:size` (where `:size` is a Fixnum or range of Fixnum).

``` ruby
puts DiffMatcher::difference(DiffMatcher::AllMatcher.new(Fixnum, :min=>3), [1, 2])
[
  : 1,
  : 2,
  - Fixnum
]
Where, - 1 missing, : 2 match_class
```

``` ruby
puts DiffMatcher::difference(DiffMatcher::AllMatcher.new(Fixnum, :size=>3..5), [1, 2])
[
  : 1,
  : 2,
  - Fixnum
]
Where, - 1 missing, : 2 match_class
```

When `actual` is an array of unknown size *and* `expected` can take
multiple forms use a `Matcher` inside of an `AllMatcher` to match
against *all* the elements in the array in any of the forms.

``` ruby
puts DiffMatcher::difference(
  DiffMatcher::AllMatcher.new(
    DiffMatcher::Matcher[Fixnum, Float]
  ),
  [1, 2.00, "3"]
)
[
  | 1,
  | 2.0,
  - Float+ "3"
]
Where, - 1 missing, + 1 additional, | 2 match_matcher
```

### Options

`:ignore_additional=>true` will match even if `actual` has additional items

``` ruby
p DiffMatcher::difference([1], [1, 2], :ignore_additional=>true)
# => nil
```

`:quiet=>true` shows only missing and additional items in the output

``` ruby
puts DiffMatcher::difference([Fixnum, 2], [1], :quiet=>true)
# => [
# => - 2
# => ]
# => Where, - 1 missing
```

#### Prefixes

The items shown in a difference are prefixed as follows:

    missing       => "- "
    additional    => "+ "
    match value   =>
    match regexp  => "~ "
    match class   => ": "
    match matcher => "| "
    match range   => ". "
    match proc    => "{ "


#### Colours

Colours (defined in colour schemes) can also appear in the difference.

Using the `:default` colour scheme items shown in a difference are coloured as follows:

    missing       => red
    additional    => yellow
    match value   =>
    match regexp  => green
    match class   => blue
    match matcher => blue
    match range   => cyan
    match proc    => cyan

Other colour schemes, eg. `:color_scheme=>:white_background` will use different colour mappings.

  

Similar gems
---

### String differs
  * <http://difflcs.rubyforge.org> (A resonably fast diff algorithm using longest common substrings)
  * <http://github.com/samg/diffy> (Provides a convenient interfaces to Unix diff)
  * <http://github.com/pvande/differ> (A simple gem for generating string diffs)
  * <http://github.com/shuber/sub_diff> (Apply regular expression replacements to strings while presenting the result in a “diff” like format)
  * <http://github.com/rattle/diffrenderer> (Takes two pieces of source text/html and creates a neato html diff output)

### Object differs
  * <http://github.com/tinogomes/ssdiff> (Super Stupid Diff)
  * <http://github.com/postmodern/tdiff> (Calculates the differences between two tree-like structures)
  * <http://github.com/Blargel/easy_diff> (Recursive diff, merge, and unmerge for hashes and arrays)

### JSON matchers
  * <http://github.com/collectiveidea/json_spec> (Easily handle JSON in RSpec and Cucumber)
  * <http://github.com/lloyd/JSONSelect> (CSS-like selectors for JSON)
  * <http://github.com/chancancode/json_expressions> (JSON matchmaking for all your API testing needs)


Why another differ?
---

This gem came about because [rspec](http://github.com/rspec/rspec-expectations) doesn't have a decent differ for matching hashes and/or JSON.
It started out as a [pull request](http://github.com/rspec/rspec-expectations/pull/79), to be implemented as a
`be_hash_matching` [rspec matcher](https://www.relishapp.com/rspec/rspec-expectations),
but seemed useful enough to be its own stand alone gem.

Out of the similar gems above, [easy_diff](http://github.com/Blargel/easy_diff) looks like a good alternative to this gem.
It has extra functionality in also being able to recursively merge hashes and arrays.
[sub_diff](http://github.com/shuber/sub_diff) can use regular expressions in its match and subsequent diff

DiffMatcher can match using not only regexes but classes and procs.
And the difference string that it outputs can be formatted in several ways as needed.

As for matching JSON, the matchers above work well, but don't allow for matching patterns.

#### Update 2012/07/14:

[json_expressions](http://github.com/chancancode/json_expressions) (as mentioned in [Ruby5 - Episode #288](http://ruby5.envylabs.com/episodes/292-episode-288-july-13th-2012)) *does*
do pattern matching and also looks like a good alternative to diff_matcher, it has the following advantages:
  * define capture symbols that can be used to extract values from the matched object
  * (if a symbol is used multiple times, it will make sure all the extracted values match)
  * can optionally match unordered arrays (diff_matcher only matches ordered arrays)
  * because it doesn't bother generating a pretty difference string it might be faster


Use with rspec
---
To use with rspec create the following custom matcher:

``` ruby
require 'diff_matcher'

module RSpec
  module Matchers
    class BeMatching
      include BaseMatcher

      def initialize(expected, opts)
        @expected = expected
        @opts = opts.update(:color_enabled=>RSpec::configuration.color_enabled?)
      end

      def matches?(actual)
        @difference = DiffMatcher::Difference.new(expected, actual, @opts)
        @difference.matching?
      end

      def failure_message_for_should
        @difference.to_s
      end
    end

    def be_matching(expected, opts={})
      Matchers::BeMatching.new(expected, opts)
    end
  end
end
```

And use it with:

``` ruby
describe "hash matcher" do
  subject { { :a=>1, :b=>2, :c=>'3', :d=>4, :e=>"additional stuff" } }
  let(:expected) { { :a=>1, :b=>Fixnum, :c=>/[0-9]/, :d=>lambda { |x| (3..5).include?(x) } } }

  it { should be_matching(expected, :ignore_additional=>true) }
  it { should be_matching(expected) }
end
```

Will result in:

```
  Failures:

    1) hash matcher
       Failure/Error: it { should be_matching(expected) }
         {
           :a=>1,
           :b=>: 2,
           :c=>~ (3),
           :d=>{ 4,
         + :e=>"additional stuff"
         }
         Where, + 1 additional, ~ 1 match_regexp, : 1 match_class, { 1 match_proc
      # ./hash_matcher_spec.rb:6:in `block (2 levels) in <top (required)>'

Finished in 0.00601 seconds
2 examples, 1 failure
```


Contributing
---

Fork, write some tests and send a pull request (bonus points for topic branches).


Status
---

Our company is using this gem to test our JSON API which has got it to a stable v1.0.0 release.

There's a [pull request](http://github.com/rspec/rspec-expectations/pull/79) to use this gem in a `be_hash_matching` 
[rspec matcher](https://www.relishapp.com/rspec/rspec-expectations).
