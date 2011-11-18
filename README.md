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
# => - 2
# => ]
# => Where, - 1 missing
```

When `actual` has additional values to the `expected`

``` ruby
puts DiffMatcher::difference([1], [1, 2])
# => [
# => + 2
# => ]
# => Where, + 1 additional
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

NB. The `: 1` from above includes a `:` prefix that shows the `1` was matched against a class (ie. `Fixnum`)

The items shown in a difference are prefixed as follows:

    missing       => "- "
    additional    => "+ "
    match value   =>
    match regexp  => "~ "
    match class   => ": "
    match proc    => "{ "

#### Colours

Colours (defined in colour schemes) can also appear in the difference.

Using the `:default` colour scheme items shown in a difference are coloured as follows:

    missing       => red
    additional    => yellow
    match value   =>
    match regexp  => green
    match class   => blue
    match proc    => cyan


`:color_scheme=>:white_background` shows difference as follows

``` ruby
    puts DiffMatcher::difference(
      { :a=>{ :a1=>11          }, :b=>[ 21, 22 ], :c=>/\d/, :d=>Fixnum, :e=>lambda { |x| (4..6).include? x } },
      { :a=>{ :a1=>10, :a2=>12 }, :b=>[ 21     ], :c=>'3' , :d=>4     , :e=>5                                },
      :color_scheme=>:white_background
    )
```


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


Contributing
---

Fork, write some tests and send a pull request (bonus points for topic branches).


Status
---

Our company is using this gem to test our JSON API which has got it to a stable v1.0.0 release.

There's a [pull request](http://github.com/rspec/rspec-expectations/pull/79) to use this gem in a `be_hash_matching` 
[rspec matcher](https://www.relishapp.com/rspec/rspec-expectations).
