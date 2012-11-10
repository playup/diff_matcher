DiffMatcher
===

[![build status](http://travis-ci.org/playup/diff_matcher.png)](http://travis-ci.org/playup/diff_matcher)
[![still maintained](http://stillmaintained.com/playupchris/diff_matcher.png)](http://stillmaintained.com/playupchris/diff_matcher)

Generates a diff by matching against user-defined matchers written in ruby.

DiffMatcher matches input data (eg. from a JSON API) against values,
ranges, classes, regexes, procs, custom matchers and/or easily composed,
nested combinations thereof to produce an easy to read diff string.

Actual input values are matched against expected matchers in the following way:

``` ruby
actual.is_a? expected  # when expected is a class
expected.match actual  # when expected is a regexp
expected.call actual   # when expected is a proc
actual == expected     # when expected is anything else
expected.diff actual   # when expected is a built-in DiffMatcher
```

Using these building blocks, more complicated nested matchers can be
composed.
eg.

``` ruby
expected = { :a=>{ :a1=>11          }, :b=>[ 21, 22 ], :c=>/\d/, :d=>Fixnum, :e=>lambda { |x| (4..6).include? x } },
actual   = { :a=>{ :a1=>10, :a2=>12 }, :b=>[ 21     ], :c=>'3' , :d=>4     , :e=>5                                },
puts DiffMatcher::difference(expected, actual, :color_scheme=>:white_background)
```

![example output](https://raw.github.com/playup/diff_matcher/master/doc/diff_matcher.gif)


Installation
---

    gem install diff_matcher


Usage
---

``` ruby
require 'diff_matcher'

DiffMatcher::difference(expected, actual, opts={})
```

#### Simple matchers

Using plain ruby objects produces the following diffs:
```
+-------------+--------+-------------+
| expected    | actual | diff        |
+-------------+--------+-------------+
| 1           | 2      | - 1+ 2      |
| 1           | 1      |             |
| String      | 1      | - String+ 1 |
| String      | "1"    |             |
| /[a-z]/     | 1      | -/[a-z]/+ 1 |
| /[a-z]/     | "a"    |             |
| 1..3        | 4      | - 1..3+ 4   |
| 1..3        | 3      |             |
| is_boolean  | true   |             |
+-------------+--------+-------------+

Where:
  is_boolean = lambda { |x| [FalseClass, TrueClass].include? x.class }
```

When `actual` is missing one of the `expected` values

``` ruby
expected = [1, 2]
puts DiffMatcher::difference(expected, [1])
# => [
# =>   1
# => - 2
# => ]
# => Where, - 1 missing
```

When `actual` has additional values to the `expected`

``` ruby
expected = [1]
puts DiffMatcher::difference(expected, [1, 2])
# => [
# =>   1
# => + 2
# => ]
# => Where, + 1 additional
```


#### More complicated matchers

Sometimes you'll need to wrap plain ruby objects with DiffMatcher's
built-in matchers, to provide extra matching abilities.

When `expected` is a `Hash`, but has optional keys, wrap the `Hash` with
a built-in `Matcher`

``` ruby
exp = {:name=>String, :age=>Fixnum}
expected = DiffMatcher::Matcher.new(exp, :optional_keys=>[:age])
puts DiffMatcher::difference(expected, {:name=>0})
# => {
# =>   :name=>- String+ 0
# => }
# => Where, - 1 missing, + 1 additional
```

When multiple `expected` values can be matched against, simply wrap them
in `Matcher`s and `||` them together

``` ruby
exp1 = Fixnum
exp2 = Float
expected = DiffMatcher::Matcher.new(exp1) || DiffMatcher::Matcher.new(exp2)
puts DiffMatcher::difference(expected, "3")
# => - Float+ "3"
# => Where, - 1 missing, + 1 additional
```

Or to do the same thing using a shorter syntax

``` ruby
exp1 = Fixnum
exp2 = Float
expected = DiffMatcher::Matcher[exp1, exp2]
puts DiffMatcher::difference(expected, "3")
# => - Float+ "3"
# => Where, - 1 missing, + 1 additional
```

When `actual` is an array of *unknown* size use an `AllMatcher` to match
against *all* the elements in the array

``` ruby
exp = Fixnum
expected = DiffMatcher::AllMatcher.new(exp)
puts DiffMatcher::difference(expected, [1, 2, "3"])
# => [
# =>   : 1,
# =>   : 2,
# =>   - Fixnum+ "3"
# => ]
# => Where, - 1 missing, + 1 additional, : 2 match_class
```


When `actual` is an array with a *limited* size use an `AllMatcher` to match
against *all* the elements in the array adhering to the limits of `:min`
and or `:max` or `:size` (where `:size` is a Fixnum or range of Fixnum).

``` ruby
exp = Fixnum
expected = DiffMatcher::AllMatcher.new(exp, :min=>3)
puts DiffMatcher::difference(expected, [1, 2])
# => [
# =>   : 1,
# =>   : 2,
# =>   - Fixnum
# => ]
# => Where, - 1 missing, : 2 match_class
```

``` ruby
exp = Fixnum
expected = DiffMatcher::AllMatcher.new(exp, :size=>3..5)
puts DiffMatcher::difference(expected, [1, 2])
# => [
# =>   : 1,
# =>   : 2,
# =>   - Fixnum
# => ]
# => Where, - 1 missing, : 2 match_class
```

When `actual` is an array of unknown size *and* `expected` can take
multiple forms use a `Matcher` to `||` them together, then wrap that
with an `AllMatcher` to match against *all* the elements in the array in
any of the forms.

``` ruby
exp1 = Fixnum
exp2 = Float
expected = DiffMatcher::AllMatcher.new( DiffMatcher::Matcher[Fixnum, Float] )
puts DiffMatcher::difference(expected, [1, 2.00, "3"])
# => [
# =>   | 1,
# =>   | 2.0,
# =>   - Float+ "3"
# => ]
# => Where, - 1 missing, + 1 additional, | 2 match_matcher
```

### Matcher options

Matcher options can be passed to `DiffMatcher::difference` or `DiffMatcher::Matcher#diff`
or instances of `DiffMatcher::Matcher`

First consider:

``` ruby
expected = DiffMatcher::Matcher.new([1])
puts expected.diff([1, 2])
# => [
# =>   1,
# => + 2
# => ]
```

Using `:ignore_additional=>true` will now match even though `actual` has additional items.

It can be used in the following ways:

``` ruby
expected = DiffMatcher::Matcher.new([1])
puts expected.diff([1, 2], :ignore_additional=>true)
# => nil
```

or

``` ruby
expected = DiffMatcher::Matcher.new([1])
puts DiffMatcher::difference(expected, [1, 2], :ignore_additional=>true)
# => nil
```

or

``` ruby
expected = DiffMatcher::Matcher.new([1], :ignore_additional=>true)
puts expected.diff([1, 2])
# => nil
```

Now consider:

``` ruby
puts DiffMatcher::Matcher.new([Fixnum, 2]).diff([1])
# => [
# =>   : 1,
# => - 2
# => ]
```

Using `:quiet=>true` will only show missing and additional items in the output
``` ruby
puts DiffMatcher::Matcher.new([Fixnum, 2]).diff([1], :quiet=>true)
# => [
# => - 2
# => ]
```

`:html_output=>true` will convert ansii escape colour codes to html spans

``` ruby
puts DiffMatcher::difference(1, 2, :html_output=>true)
# => <pre>
# => <span style="color:red">- <b>1</b></span><span style="color:yellow">+ <b>2</b></span>
# => Where, <span style="color:red">- <b>1 missing</b></span>, <span style="color:yellow">+ <b>1 additional</b></span>
# => </pre>
```

#### Prefixes

A difference string is similar in appereance to the `.inspect` of plain
ruby objects, however the matched elements it contains are prefixed
in the following way:

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
To use with rspec, create a custom matcher. The following example matcher works with rspec-1.2.4 and up.

``` ruby
require 'diff_matcher'

# Uses the diff_matcher gem to provide advanced matching abilities, along with nice visual representation of the
# diff between actual and expected. The functionality set is very helpful for comparing hashes.
#
# Usage examples:
#  it { should be_matching(my_var) }
#  it { should be_matching(my_var).with_options(ignore_additional: true) }
#
# Options: by default, color_enabled is controlled by Rspec, and quiet is set to true.
RSpec::Matchers.define :be_matching do |expected|
  match do |actual|
    options = { color_enabled: RSpec::configuration.color_enabled?, quiet: true }.merge(@options || {})
    @difference = DiffMatcher::Difference.new(expected, actual, options)
    @difference.matching?
  end

  chain :with_options do |options|
    @options = options
  end

  failure_message_for_should do |actual|
    "diff is:\n" + @difference.to_s
  end

  failure_message_for_should_not do |actual|
    "diff is:\n" + @difference.to_s
  end

  description do
    "match via DiffMatcher #{expected}" + (@options.blank? ? '' : " with options: #{@options}")
  end
end
```

And use it with:

``` ruby
describe "hash matcher" do
  subject { { :a=>1, :b=>2, :c=>'3', :d=>4, :e=>"additional stuff" } }
  let(:expected) { { :a=>1, :b=>Fixnum, :c=>/[0-9]/, :d=>lambda { |x| (3..5).include?(x) } } }

  it { should be_matching(expected).with_options(:ignore_additional=>true) }
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

Think up something DiffMatcher *can't* do!  :)
Fork, write some tests and send a pull request (bonus points for topic branches), or just submit an issue.


Status
---

Our company is using this gem to test our JSON API which has got above and beyond a stable v1.0.0 release.

There's a [pull request](http://github.com/rspec/rspec-expectations/pull/79) to use this gem in a `be_hash_matching` 
[rspec matcher](https://www.relishapp.com/rspec/rspec-expectations).
