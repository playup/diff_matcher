require "spec_helper"

RUBY_1_9 = (RUBY_VERSION =~ /^1\.9/)

def opts_to_s(opts)
  opts_strs = opts.map { |k,v| ":#{k}=>#{v}" if v }.compact
  opts_strs.size > 0 ? ", " + opts_strs * ", " : ""
end

def fix_EOF_problem(s)
  # <<-EOF isn't working like its meant to :(
  whitespace = s.split("\n")[-1][/^[ ]+/]
  indentation = whitespace ? whitespace.size : 0
  s.gsub("\n#{" " * indentation}", "\n").strip
end

describe DiffMatcher do
  subject { DiffMatcher::difference(expected, actual, opts) }

  shared_examples_for "a differ" do |expected, same, different, difference="", opts={}|
    context "with #{opts.size > 0 ? opts_to_s(opts) : "no opts"}" do
      describe "difference(#{expected.inspect}, #{same.inspect}#{opts_to_s(opts)})" do
        let(:expected) { expected }
        let(:actual  ) { same     }
        let(:opts    ) { opts     }

        it { should be_nil }
      end

      describe "#new(#{expected.inspect}, #{different.inspect}#{opts_to_s(opts)})" do
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

  describe "when expected is an instance," do
    context "of Fixnum," do
      expected, same, different =
        1,
        1,
        2

      it_behaves_like "a differ", expected, same, different,
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

      it_behaves_like "a differ", expected, same, different,
        <<-EOF
        - "a"+ "b"
        Where, - 1 missing, + 1 additional
        EOF

      context "when actual is of a different class" do
        different = 0

        it_behaves_like "a differ", expected, same, different,
          <<-EOF
          - "a"+ 0
          Where, - 1 missing, + 1 additional
          EOF
      end

      context "when actual is nil" do
        different = nil

        it_behaves_like "a differ", expected, same, different,
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

      it_behaves_like "a differ", expected, same, different,
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

      it_behaves_like "a differ", expected, same, different,
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

        it_behaves_like "a differ", expected, same, different,
          <<-EOF, :ignore_additional=>true
          [
            - 1+ 0,
          + 3
          ]
          Where, - 1 missing, + 2 additional
          EOF

        it_behaves_like "a differ", expected, same, different,
          <<-EOF, :ignore_additional=>true, :quiet=>true
          [
            - 1+ 0
          ]
          Where, - 1 missing, + 1 additional
          EOF

        it_behaves_like "a differ", expected, same, different,
          <<-EOF, :ignore_additional=>true, :verbose=>true
          [
            - 1+ 0,
            2,
          + 3
          ]
          Where, - 1 missing, + 2 additional
          EOF
      end

      context "where actual has missing items" do
        expected, same, different =
          [ 1, 2, 3 ],
          [ 1, 2, 3 ],
          [ 1, 2    ]

        it_behaves_like "a differ", expected, same, different,
          <<-EOF
          [
          - 3
          ]
          Where, - 1 missing
          EOF

        it_behaves_like "a differ", expected, same, different,
          <<-EOF, :verbose=>true
          [
            1,
            2,
          - 3
          ]
          Where, - 1 missing
          EOF
      end
    end

    context "of Hash," do
      expected, same, different =
        { "a"=>1 },
        { "a"=>1 },
        { "a"=>2 }

      it_behaves_like "a differ", expected, same, different,
        <<-EOF
        {
          "a"=>- 1+ 2
        }
        Where, - 1 missing, + 1 additional
        EOF

      context "with keys of differing classes" do
        expected, same, different =
          { "a"=>{ "b"=>1 } },
          { "a"=>{ "b"=>1 } },
          { "a"=>[ "b", 1 ] }

        it_behaves_like "a differ", expected, same, different,
          <<-EOF
          {
            "a"=>- {"b"=>1}+ ["b", 1]
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
          it_behaves_like "a differ", expected, same, different,
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
  end

  describe "when expected is," do
    context "a class," do
      expected, same, different =
        String,
        "a",
        1

      it_behaves_like "a differ", expected, same, different,
        <<-EOF
        - String+ 1
        Where, - 1 missing, + 1 additional
        EOF
    end
  end

  describe "when expected is," do
    context "a Regex," do
      expected, same, different =
        /[a-z]/,
        "a",
        "A"

      it_behaves_like "a differ", expected, same, different,
        <<-EOF
        - /[a-z]/+ "A"
        Where, - 1 missing, + 1 additional
        EOF

      context "and when actual is not a String," do
        different = :a

        it_behaves_like "a differ", expected, same, different,
          <<-EOF
          - /[a-z]/+ :a
          Where, - 1 missing, + 1 additional
          EOF
      end
    end
  end

  describe "when expected is," do
    context "a proc," do
      expected, same, different =
        lambda { |x| [FalseClass, TrueClass].include? x.class },
        true,
        "true"

      it_behaves_like "a differ", expected, same, different,
        /- #<Proc.*?>\+ \"true\"\nWhere, - 1 missing, \+ 1 additional/
    end
  end

  context "when expected has multiple items," do
    expected, same, different =
      [ 1,  2, /\d/, Fixnum, lambda { |x| (4..6).include? x } ],
      [ 1,  2, "3" , 4     , 5                                ],
      [ 0,  2, "3" , 4     , 5                                ]

    describe "it shows regex, class, proc matches and" do
      it_behaves_like "a differ", expected, same, different,
        <<-EOF
        [
          - 1+ 0,
          ~ (3),
          : 4,
          { 5
        ]
        Where, - 1 missing, + 1 additional, ~ 1 match_regexp, : 1 match_class, { 1 match_proc
        EOF
    end

    describe "it doesn't show matches and" do
      it_behaves_like "a differ", expected, same, different,
        <<-EOF, :quiet=>true
        [
          - 1+ 0
        ]
        Where, - 1 missing, + 1 additional
        EOF
    end

    describe "it shows all matches and" do
      it_behaves_like "a differ", expected, same, different,
        <<-EOF ,:verbose=>true
        [
          - 1+ 0,
          2,
          ~ (3),
          : 4,
          { 5
        ]
        Where, - 1 missing, + 1 additional, ~ 1 match_regexp, : 1 match_class, { 1 match_proc
        EOF
    end

    describe "it shows matches in color and" do
      it_behaves_like "a differ", expected, same, different,
        <<-EOF ,:verbose=>true, :color_scheme=>:default
        \e[0m[
        \e[0m  \e[31m- \e[1m1\e[0m\e[33m+ \e[1m0\e[0m,
        \e[0m  2,
        \e[0m  \e[32m~ \e[0m\e[32m(\e[1m3\e[0m\e[32m)\e[0m\e[0m,
        \e[0m  \e[34m: \e[1m4\e[0m,
        \e[0m  \e[36m{ \e[1m5\e[0m
        \e[0m]
        Where, \e[31m- \e[1m1 missing\e[0m, \e[33m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
        EOF

      context "on a white background" do
        it_behaves_like "a differ", expected, same, different,
          <<-EOF ,:verbose=>true, :color_scheme=>:white_background
          \e[0m[
          \e[0m  \e[31m- \e[1m1\e[0m\e[35m+ \e[1m0\e[0m,
          \e[0m  2,
          \e[0m  \e[32m~ \e[0m\e[32m(\e[1m3\e[0m\e[32m)\e[0m\e[0m,
          \e[0m  \e[34m: \e[1m4\e[0m,
          \e[0m  \e[36m{ \e[1m5\e[0m
          \e[0m]
          Where, \e[31m- \e[1m1 missing\e[0m, \e[35m+ \e[1m1 additional\e[0m, \e[32m~ \e[1m1 match_regexp\e[0m, \e[34m: \e[1m1 match_class\e[0m, \e[36m{ \e[1m1 match_proc\e[0m
          EOF
      end
    end
  end
end
