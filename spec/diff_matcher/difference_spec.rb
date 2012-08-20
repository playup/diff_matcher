require "spec_helper"

def opts_to_s(opts)
  opts_strs = opts.map { |k,v| ":#{k}=>#{v}" if v }.compact
  opts_strs.size > 0 ? ", " + opts_strs * ", " : ""
end

def fix_EOF_problem(s)
  # <<-EOF isn't working like its meant to :(
  whitespace = s.split("\n")[-1][/^[ ]+/]
  indentation = whitespace ? whitespace.size : 0
  s.gsub("\n#{" " * indentation}", "\n").tap { |result|
    result.strip! if whitespace
  }
end


shared_examples_for "an or-ed matcher" do |expected, expected2, same, different, difference, opts|
  opts ||= {}
  context "where expected=#{expected.inspect}, expected2=#{expected2.inspect}" do
    describe "diff(#{same.inspect}#{opts_to_s(opts)})" do
      let(:expected ) { expected }
      let(:expected2) { expected }
      let(:actual   ) { same     }
      let(:opts     ) { opts     }

      it { should be_nil }
    end

    describe "diff(#{different.inspect}#{opts_to_s(opts)})" do
      let(:expected ) { expected  }
      let(:expected2) { expected }
      let(:actual   ) { different }
      let(:opts     ) { opts      }

      it { should_not be_nil } unless RUBY_1_9
      it { should == fix_EOF_problem(difference) } if RUBY_1_9
    end
  end
end


describe DiffMatcher::Matcher do
  expected, expected2, same, different, difference =
    {:nombre => String   , :edad   => Integer },
    {:name   => String   , :age    => Integer },
    {:name   => "Peter"  , :age    => 21      },
    {:name   => 21       , :age    => 21      },
    "{\n  :name=>\e[31m- \e[1mString\e[0m\e[33m+ \e[1m21\e[0m,\n  :age=>\e[34m: \e[1m21\e[0m\n}\n"

  describe "DiffMatcher::Matcher[expected, expected2]," do
    subject { DiffMatcher::Matcher[expected, expected2].diff(actual) }

    it_behaves_like "an or-ed matcher", expected, expected2, same, different, difference

    context "when Matchers are or-ed it works the same" do
      subject { (DiffMatcher::Matcher[expected] | DiffMatcher::Matcher[expected2]).diff(actual) }

      it_behaves_like "an or-ed matcher", expected, expected2, same, different, difference
    end

    context "expecteds are in different order it still uses the closest dif" do
      subject { DiffMatcher::Matcher[expected2, expected].diff(actual) }

      it_behaves_like "an or-ed matcher", expected2, expected, same, different, difference
    end
  end
end


describe "DiffMatcher::AllMatcher[expected]" do
  let(:all_matcher) { DiffMatcher::AllMatcher[expected] }
  let(:expected ) { 1 }

  describe "#diff(actual)" do
    subject { all_matcher.diff(actual) }

    context "when all match" do
      let(:actual) { [1, 1, 1] }

      it { should eql nil }
    end

    context "when not all match" do
      let(:actual) { [1, 2, 1] }

      it { should eql "[\n  1,\n  \e[31m- \e[1m1\e[0m\e[33m+ \e[1m2\e[0m,\n  1\n]\n" }
    end

    context "when actual is not an array" do
      let(:actual) { 'a' }

      it { should eql "\e[31m- \e[1m[...]\e[0m\e[33m+ \e[1m\"a\"\e[0m" }
    end
  end
end


shared_examples_for "a diff matcher" do |expected, same, different, difference, opts|
  opts ||= {}
  context "with #{opts.size > 0 ? opts_to_s(opts) : "no opts"}" do
    describe "difference(#{expected.inspect}, #{same.inspect}#{opts_to_s(opts)})" do
      let(:expected) { expected }
      let(:actual  ) { same     }
      let(:opts    ) { opts     }

      it { should be_nil }
    end

    describe "difference(#{expected.inspect}, #{different.inspect}#{opts_to_s(opts)})" do
      let(:expected) { expected  }
      let(:actual  ) { different }
      let(:opts    ) { opts      }

      it { should_not be_nil } unless RUBY_1_9
      it {
        difference.is_a?(Regexp) ?
          should =~ difference :
          should == fix_EOF_problem(difference)
      } if RUBY_1_9
    end
  end
end

describe "DiffMatcher::Matcher[expected].diff(actual, opts)" do
  subject { DiffMatcher::Matcher[expected].diff(actual, opts) }

  describe "when expected is an instance," do
    context "of Fixnum," do
      expected, same, different =
        1,
        1,
        2

      it_behaves_like "a diff matcher", expected, same, different,
        "\e[31m- \e[1m1\e[0m\e[33m+ \e[1m2\e[0m"
    end
  end

  describe "when expected is an instance," do
    context "of Hash, with optional keys" do
      expected, same, different =
        {:a=>1, :b=>Fixnum},
        {:a=>1},
        {:a=>2}

      it_behaves_like "a diff matcher", expected, same, different,
        "{\n  :a=>\e[31m- \e[1m1\e[0m\e[33m+ \e[1m2\e[0m\n}\n",
        {:optional_keys=>[:b]}
    end
  end
end


describe "DiffMatcher::difference(expected, actual, opts)" do
  subject { DiffMatcher::difference(expected, actual, opts) }

  describe "when expected is an instance," do
    context "of Fixnum," do
      expected, same, different =
        1,
        1,
        2

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - 1+ 2
        Where, - 1 missing, + 1 additional
        EOF
    end

    context "of String," do
      expected, same, different =
        "a",
        "a",
        "b"

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - "a"+ "b"
        Where, - 1 missing, + 1 additional
        EOF

      context "when actual is of a different class" do
        different = 0

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          - "a"+ 0
          Where, - 1 missing, + 1 additional
          EOF
      end

      context "when actual is nil" do
        different = nil

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          - "a"+ nil
          Where, - 1 missing, + 1 additional
          EOF
      end
    end

    context "of nil," do
      expected, same, different =
        nil,
        nil,
        false

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - nil+ false
        Where, - 1 missing, + 1 additional
        EOF
    end

    context "of Array," do
      expected, same, different =
        [ 1 ],
        [ 1 ],
        [ 2 ]

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        [
          - 1+ 2
        ]
        Where, - 1 missing, + 1 additional
        EOF

      context "where actual has additional items" do
        expected, same, different =
          [ 1, 2    ],
          [ 1, 2, 3 ],
          [ 0, 2, 3 ]

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF, :ignore_additional=>true
          [
            - 1+ 0,
            2,
          + 3
          ]
          Where, - 1 missing, + 2 additional
          EOF

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF, :ignore_additional=>true, :quiet=>true
          [
            - 1+ 0
          ]
          Where, - 1 missing, + 1 additional
          EOF

        context "where actual has additional items, it summarizes the Array item with ... and" do
          expected, same, different =
            [ 1, 2        ],
            [ 1, 2, [ 3 ] ],
            [ 0, 2, [ 3 ] ]

          it_behaves_like "a diff matcher", expected, same, different,
            <<-EOF, :ignore_additional=>true
            [
              - 1+ 0,
              2,
            + [...]
            ]
            Where, - 1 missing, + 2 additional
            EOF
        end

        context "where actual has additional items, it summarizes the Hash item with ... and" do
          expected, same, different =
            [ 1, 2                 ],
            [ 1, 2, { :a=> [ 3 ] } ],
            [ 0, 2, { :a=> [ 3 ] } ]

          it_behaves_like "a diff matcher", expected, same, different,
            <<-EOF, :ignore_additional=>true
            [
              - 1+ 0,
              2,
            + {...}
            ]
            Where, - 1 missing, + 2 additional
            EOF
        end
      end

      context "where actual has missing items" do
        expected, same, different =
          [ 1, 2, 3 ],
          [ 1, 2, 3 ],
          [ 1, 2    ]

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF, { :quiet => true }
          [
          - 3
          ]
          Where, - 1 missing
          EOF

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          [
            1,
            2,
          - 3
          ]
          Where, - 1 missing
          EOF
      end

      context "where actual is not an array, it summarizes the diff with ... and" do
        expected, same, different =
          [ 1 ],
          [ 1 ],
          { 0 => 1 }

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          - [...]+ {...}
          Where, - 1 missing, + 1 additional
          EOF
      end
    end

    context "of an Array derived class," do
      class ArrayChild < Array; end
      expected, same, different =
        ArrayChild[ 1 ],
        ArrayChild[ 1 ],
        ArrayChild[ 2 ]

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        [
          - 1+ 2
        ]
        Where, - 1 missing, + 1 additional
        EOF
    end

    context "of Range," do
      expected, same, different =
        (1..3),
        2,
        4

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - 1..3+ 4
        Where, - 1 missing, + 1 additional
        EOF
    end

    context "of Hash," do
      expected, same, different =
        { "a"=>1 },
        { "a"=>1 },
        { "a"=>2 }

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        {
          "a"=>- 1+ 2
        }
        Where, - 1 missing, + 1 additional
        EOF

      context "with values of differing classes" do
        expected, same, different =
          { "a"=>{ "b"=>1 } },
          { "a"=>{ "b"=>1 } },
          { "a"=>[ "b", 1 ] }

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          {
            "a"=>- {...}+ [...]
          }
          Where, - 1 missing, + 1 additional
          EOF
      end

      context "with matching hash descendents" do
        expected, same, different =
          { "a"=>{ "b"=>{ "c"=>1 } } },
          { "a"=>{ "b"=>{ "c"=>1 } } },
          {        "b"=>{ "c"=>1 }   }

        describe "it won't match the descendents" do
          it_behaves_like "a diff matcher", expected, same, different,
            <<-EOF
            {
            - "a"=>{"b"=>{"c"=>1}},
            + "b"=>{"c"=>1}
            }
            Where, - 1 missing, + 1 additional
            EOF
        end
      end
    end

    context "of a Hash derived class," do
      class HashChild < Hash; end
      expected, same, different =
        HashChild["a",1],
        HashChild["a",1],
        HashChild["a",2]

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        {
          "a"=>- 1+ 2
        }
        Where, - 1 missing, + 1 additional
        EOF
    end
  end

  describe "when expected is," do
    context "a class," do
      expected, same, different =
        String,
        "a",
        1

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - String+ 1
        Where, - 1 missing, + 1 additional
        EOF
    end

    context "a Regex," do
      expected, same, different =
        /[a-z]/,
        "a",
        "A"

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - /[a-z]/+ "A"
        Where, - 1 missing, + 1 additional
        EOF

      context "and when actual is not a String," do
        different = :a

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          - /[a-z]/+ :a
          Where, - 1 missing, + 1 additional
          EOF
      end
    end

    context "a proc," do
      expected, same, different =
        lambda { |x| [FalseClass, TrueClass].include? x.class },
        true,
        "true"

      it_behaves_like "a diff matcher", expected, same, different,
        /- #<Proc.*?>\+ \"true\"\nWhere, - 1 missing, \+ 1 additional/

      context "that defines another diff matcher" do
        expected, same, different =
          lambda { |array| array.all? { |item| DiffMatcher::Difference.new(String, item).matching? } },
          ["A", "B", "C"],
          ["A", "B", 0  ]

        it_behaves_like "a diff matcher", expected, same, different,
          /- #<Proc.*?>\+ \[\"A\", \"B\", 0\]\nWhere, - 1 missing, \+ 1 additional/
      end
    end

    context "a DiffMatcher::Matcher," do
      expected, same, different =
        DiffMatcher::Matcher[String],
        "a",
        1

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        - String+ 1
        Where, - 1 missing, + 1 additional
        EOF

      context "or-ed with another DiffMatcher::Matcher," do
        expected, same, different =
          DiffMatcher::Matcher[Fixnum] | DiffMatcher::Matcher[String],
          "a",
          1.0

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          - String+ 1.0
          Where, - 1 missing, + 1 additional
          EOF
      end
    end

    context "a DiffMatcher::AllMatcher," do
      expected, same, different =
        DiffMatcher::AllMatcher[String],
        %w(ay be ci),
        ["a", 2, "c"]

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        [
          : "a",
          - String+ 2,
          : "c"
        ]
        Where, - 1 missing, + 1 additional, : 2 match_class
        EOF

      end

      context "with a min restriction" do
        expected, same, different =
          DiffMatcher::AllMatcher.new(String, :min=>3),
          %w(ay be ci),
          %w(ay be)

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          [
            : "ay",
            : "be",
          - String
          ]
          Where, - 1 missing, : 2 match_class
          EOF
      end

      context "with a max restriction" do
        expected, same, different =
          DiffMatcher::AllMatcher.new(String, :max=>2),
          %w(ay be),
          %w(ay be ci)

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          [
            : "ay",
            : "be",
          + "ci"
          ]
          Where, + 1 additional, : 2 match_class
          EOF
      end

      context "with a size restriction" do
        expected, same, different =
          DiffMatcher::AllMatcher.new(String, :size=>2),
          %w(ay be),
          %w(ay be ci)

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          [
            : "ay",
            : "be",
          + "ci"
          ]
          Where, + 1 additional, : 2 match_class
          EOF
      end

      context "with a size restriction range" do
        expected, same, different =
          DiffMatcher::AllMatcher.new(String, :size=>0..2),
          %w(ay be),
          %w(ay be ci)

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          [
            : "ay",
            : "be",
          + "ci"
          ]
          Where, + 1 additional, : 2 match_class
          EOF
      end
    end

    context "a DiffMatcher::AllMatcher using an or-ed DiffMatcher::Matcher," do
      expected, same, different =
        DiffMatcher::AllMatcher[ DiffMatcher::Matcher[Fixnum, Float] ],
        [1, 2.0, 3],
        [1, "2", 3]

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        [
          | 1,
          - Float+ "2",
          | 3
        ]
        Where, - 1 missing, + 1 additional, | 2 match_matcher
        EOF

      context "more complex," do
        expected, same, different =
          DiffMatcher::AllMatcher[
            DiffMatcher::Matcher[
              {:nombre=>String, :edad=>Fixnum},
              {:name=>String, :age=>Fixnum}
            ]
          ],
          [
            {:name=>"Alice", :age=>10},
            {:name=>"Bob"  , :age=>20},
            {:name=>"Con"  , :age=>30}
          ],
          [
            {:name=>"Alice", :age=>10 },
            {:name=>"Bob"  , :age=>nil},
            {:nombre=>"Con", :edad=>30}
          ]

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          [
            | {:name=>"Alice", :age=>10},
            {
              :name=>: "Bob",
              :age=>- Fixnum+ nil
            },
            | {:nombre=>"Con", :edad=>30}
          ]
          Where, - 1 missing, + 1 additional, : 1 match_class, | 2 match_matcher
          EOF
    end
  end

  context "when expected has multiple items," do
    expected, same, different =
      [ 1,  2, /\d/, Fixnum, 4..6 , lambda { |x| x % 6 == 0 } ],
      [ 1,  2, "3" , 4     , 5    , 6                         ],
      [ 0,  2, "3" , 4     , 5    , 6                         ]

    describe "it shows regex, class, range, proc matches and matches" do
      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        [
          - 1+ 0,
          2,
          ~ "(3)",
          : 4,
          . 5,
          { 6
        ]
        Where, - 1 missing, + 1 additional, ~ 1 match_regexp, : 1 match_class, . 1 match_range, { 1 match_proc
        EOF
    end

    describe "it doesn't show matches" do
      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF, :quiet=>true
        [
          - 1+ 0
        ]
        Where, - 1 missing, + 1 additional
        EOF
    end

    describe "it shows all matches" do
      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        [
          - 1+ 0,
          2,
          ~ "(3)",
          : 4,
          . 5,
          { 6
        ]
        Where, - 1 missing, + 1 additional, ~ 1 match_regexp, : 1 match_class, . 1 match_range, { 1 match_proc
        EOF
    end

    describe "it shows matches in color" do
      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF , :color_scheme=>:default
        \e[0m[
        \e[0m  \e[31m- \e[1m1\e[0m\e[33m+ \e[1m0\e[0m,
        \e[0m  2,
        \e[0m  \e[32m~ \e[0m"\e[32m(\e[1m3\e[0m\e[32m)\e[0m"\e[0m,
        \e[0m  \e[34m: \e[1m4\e[0m,
        \e[0m  \e[36m. \e[1m5\e[0m,
        \e[0m  \e[36m{ \e[1m6\e[0m
        \e[0m]
        Where, \e[31m- \e[1m1 missing\e[0m, \e[33m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m. \e[1m1 match_range\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
        EOF

      context "on a white background" do
        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF , :color_scheme=>:white_background
          \e[0m[
          \e[0m  \e[31m- \e[1m1\e[0m\e[35m+ \e[1m0\e[0m,
          \e[0m  2,
          \e[0m  \e[32m~ \e[0m"\e[32m(\e[1m3\e[0m\e[32m)\e[0m"\e[0m,
          \e[0m  \e[34m: \e[1m4\e[0m,
          \e[0m  \e[36m. \e[1m5\e[0m,
          \e[0m  \e[36m{ \e[1m6\e[0m
          \e[0m]
          Where, \e[31m- \e[1m1 missing\e[0m, \e[35m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m. \e[1m1 match_range\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
          EOF
      end

      context "color_enabled can be set on the class" do
        before { DiffMatcher::Difference::color_enabled = true }

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          \e[0m[
          \e[0m  \e[31m- \e[1m1\e[0m\e[33m+ \e[1m0\e[0m,
          \e[0m  2,
          \e[0m  \e[32m~ \e[0m"\e[32m(\e[1m3\e[0m\e[32m)\e[0m"\e[0m,
          \e[0m  \e[34m: \e[1m4\e[0m,
          \e[0m  \e[36m. \e[1m5\e[0m,
          \e[0m  \e[36m{ \e[1m6\e[0m
          \e[0m]
          Where, \e[31m- \e[1m1 missing\e[0m, \e[33m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m. \e[1m1 match_range\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
          EOF
      end

      context "color_scheme can be set on the class" do
        before { DiffMatcher::Difference::color_scheme = :white_background }

        it_behaves_like "a diff matcher", expected, same, different,
          <<-EOF
          \e[0m[
          \e[0m  \e[31m- \e[1m1\e[0m\e[35m+ \e[1m0\e[0m,
          \e[0m  2,
          \e[0m  \e[32m~ \e[0m"\e[32m(\e[1m3\e[0m\e[32m)\e[0m"\e[0m,
          \e[0m  \e[34m: \e[1m4\e[0m,
          \e[0m  \e[36m. \e[1m5\e[0m,
          \e[0m  \e[36m{ \e[1m6\e[0m
          \e[0m]
          Where, \e[31m- \e[1m1 missing\e[0m, \e[35m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m. \e[1m1 match_range\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
          EOF
      end
    end

    describe "it shows matches in color when color is configured in Difference" do
      before do
        DiffMatcher::Difference.configure do |config|
          config.color_enabled = true
        end
      end

      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF
        \e[0m[
        \e[0m  \e[31m- \e[1m1\e[0m\e[35m+ \e[1m0\e[0m,
        \e[0m  2,
        \e[0m  \e[32m~ \e[0m"\e[32m(\e[1m3\e[0m\e[32m)\e[0m"\e[0m,
        \e[0m  \e[34m: \e[1m4\e[0m,
        \e[0m  \e[36m. \e[1m5\e[0m,
        \e[0m  \e[36m{ \e[1m6\e[0m
        \e[0m]
        Where, \e[31m- \e[1m1 missing\e[0m, \e[35m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m. \e[1m1 match_range\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
        EOF
    end

    describe "it shows matches in html" do
      it_behaves_like "a diff matcher", expected, same, different,
        <<-EOF , :color_scheme => :white_background, :html_output=>true
        <pre>
        [
          <span style=\"color:red\">- <b>1</b></span><span style=\"color:magenta\">+ <b>0</b></span>,
          2,
          <span style=\"color:green\">~ </b></span>\"<span style=\"color:green\">(<b>3</b></span><span style=\"color:green\">)</b></span>\"</b></span>,
          <span style=\"color:blue\">: <b>4</b></span>,
          <span style=\"color:cyan\">. <b>5</b></span>,
          <span style=\"color:cyan\">{ <b>6</b></span>
        ]
        Where, <span style=\"color:red\">- <b>1 missing</b></span>, <span style=\"color:magenta\">+ <b>1 additional</b></span>, <span style=\"color:green\">~ <b>1 match_regexp</b></span>, <span style=\"color:blue\">: <b>1 match_class</b></span>, <span style=\"color:cyan\">. <b>1 match_range</b></span>, <span style=\"color:cyan\">{ <b>1 match_proc</b></span>
        </pre>
        EOF
    end
  end
end
