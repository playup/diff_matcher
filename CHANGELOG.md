# Changelog

### v2.3.2

  Summarize Hash and Array output in diff with "..."
```
  eg.
  - [...]+ {...}
```

### v2.2.3

  set color_enabled/color_scheme on the class
  
  (ie. so it can be used by default)

### v2.2.2

  BUGFIX for AllMatcher
  
  - return a diff instead of raising an exception
  - (raising an exception was a bad idea as it blew up the entire match
     when used in conjuction with an or-matcher, or embedded into other
     matchers)

### v2.2.1

  AllMatcher also accepts a size (Fixnum or Range)

### v2.2.0

  Added Matcher and AllMatcher
    - Matcher returns the *closest* diff.
  Added :min, :max args to AllMatcher and :optional_keys to Matcher
  Added range matcher

### v2.0.0

  Remove :verbose option
  
  More often than not users want this as the default.

### v1.0.1

* BUGFIX for ruby 1.8.7

### v1.0.0

* initial release (as a gem in the wild)
