module DiffMatcher

  def self.difference(expected, actual, opts={})
    difference = Difference.new(expected, actual, opts)
    difference.matching? ? nil : difference.to_s
  end

  class Matcher
    attr_reader :expecteds

    def self.[](*expecteds)
      expecteds.inject(nil) { |obj, e| obj ? obj | new(e) : new(e) }
    end

    def initialize(expected, opts={})
      @expecteds = [expected]
      @expected_opts = {expected => opts}
    end

    def |(other)
      #"(#{expecteds.join(",")}|#{other.expecteds.join(",")})"
      tap { @expecteds += other.expecteds }
    end

    def expected(e, actual)
      e
    end

    def expected_opts(e)
      @expected_opts.fetch(e, {})
    end

    def diff(actual, opts={})
      difs = []
      matched = @expecteds.any? { |e|
        d = DiffMatcher::Difference.new(expected(e, actual), actual, opts.merge(expected_opts(e)))
        unless d.matching?
          difs << [ d.dif_count, d.dif ]
        end
        d.matching?
      }
      unless matched
        count, dif = difs.sort.last
        dif
      end
    end
  end

  class NotAnArray < Exception; end
  class AllMatcher < Matcher
    def expected(e, actual)
      opts = expected_opts(e)
      size = opts[:size]
      case size
      when Fixnum
        min = size
        max = size
      when Range
        min = size.first
        max = size.last
      else
        min = opts[:min] || 0
        max = opts[:max] || 1_000_000 # MAXINT?
      end
      size = actual.size
      size = size > min ? (size < max ? size : max) : min
      [e]*size
    end
  end

  class Difference
    RESET   = "\e[0m"
    BOLD    = "\e[1m"

    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"

    DEFAULT_COLOR_SCHEME = {
        :missing       => [RED   , "-"],
        :additional    => [YELLOW, "+"],
        :match_value   => [nil   , nil],
        :match_regexp  => [GREEN , "~"],
        :match_class   => [BLUE  , ":"],
        :match_matcher => [BLUE  , "|"],
        :match_range   => [CYAN  , "."],
        :match_proc    => [CYAN  , "{"]
    }

    class << self
      attr_reader :color_scheme
      attr_writer :color_enabled, :color_schemes

      def color_schemes
        @color_schemes ||= {
          :default          => DEFAULT_COLOR_SCHEME,
          :white_background => DEFAULT_COLOR_SCHEME.merge(
            :additional    => [MAGENTA, "+"]
          )
        }
      end

      def color_scheme=(value)
        @color_scheme = color_schemes[value]
      end

      def color_enabled
        @color_enabled.nil? ? !!@color_scheme : @color_enabled
      end
    end

    def initialize(expected, actual, opts={})
      @opts = opts
      @ignore_additional = opts[:ignore_additional]
      @quiet             = opts[:quiet]
      @color_scheme      = self.class.color_schemes[opts[:color_scheme]] || self.class.color_scheme || self.class.color_schemes[:default]
      @color_enabled     = (opts[:color_enabled].nil? && opts[:color_scheme].nil?) ? self.class.color_enabled : !!opts[:color_scheme] || opts[:color_enabled]
      @optional_keys = opts.delete(:optional_keys) || []
      @dif_count = 0
      @difference = difference(expected, actual)
    end

    def matching?
      @match ||= @difference ? item_types.map { |item_type|
        @color_scheme[item_type]
      }.inject(0) { |count, (color, prefix)|
        count + @difference.scan("#{color}#{prefix}").size
      } == 0 : true
    end

    def to_s
      if @difference
        msg = "\e[0m" + @difference.split("\n").join("\n\e[0m")
        where = @color_scheme.keys.collect { |item_type|
          unless item_type == :match_value
            color, prefix = @color_scheme[item_type]
            count = msg.scan("#{color}#{prefix}").size
            @dif_count += count if [:missing, :additional].include? item_type
            "#{color}#{prefix} #{BOLD}#{count} #{item_type}#{RESET}" if count > 0
          end
        }.compact.join(", ")
        msg <<  "\nWhere, #{where}" if where.size > 0

        @color_enabled ? msg : msg.gsub(/\e\[\d+m/, "")
      end
    end

    def dif_count
      @dif_count
    end

    def dif
      @difference
    end

    private

    def item_types
      @item_types ||= @ignore_additional ? [:missing] : [:missing, :additional]
    end

    def item_types_shown
      @item_types_shown ||= lambda {
        ret = [:different] + item_types
        ret += [:additional] unless @quiet
        ret.uniq
      }.call
    end

    def matches_shown
      @matches_shown ||= lambda {
        ret = []
        unless @quiet
          ret += [:match_matcher, :match_class, :match_range, :match_proc, :match_regexp]
          ret += [:match_value]
        end
        ret
      }.call
    end

    def difference(expected, actual)
      if actual.is_a? expected.class
        left = diff(expected, actual)
        right = diff(actual, expected)
        items_to_s(
          expected,
          (item_types_shown).inject([]) { |a, method|
            a + send(method, left, right, expected).compact.map { |item| markup(method, item) }
          }
        )
      else
        difference_to_s(expected, actual)
      end
    end

    def diff(expected, actual)
      if expected.is_a?(Hash)
        expected.keys.inject({}) { |h, k|
          h.update(k => actual.has_key?(k) ? difference(actual[k], expected[k]) : expected[k])
        }
      elsif expected.is_a?(Array)
        expected, actual = [expected, actual].map { |x| x.each_with_index.inject({}) { |h, (v, i)| h.update(i=>v) } }
        diff(expected, actual)
      else
        actual
      end if expected.is_a? actual.class
    end

    def compare(right, expected, default=nil)
      case expected
      when Hash, Array
        right && right.keys.tap { |keys| keys.sort if expected.is_a? Array }.map { |k|
          yield k
        }
      else
        [default]
      end
    end

    def different(left, right, expected)
      compare(right, expected, difference_to_s(right, left)) { |k|
        "#{"#{k.inspect}=>" if expected.is_a? Hash}#{right[k]}" if right[k] and left.has_key?(k)
      }
    end

    def missing(left, right, expected)
      compare(left, expected) { |k|
        "#{"#{k.inspect}=>" if expected.is_a? Hash}#{left[k].inspect}" unless right.has_key?(k) || @optional_keys.include?(k)
      }
    end

    def additional(left, right, expected)
      missing(right, left, expected)
    end

    def match?(expected, actual)
      case expected
        when Matcher
          d = expected.diff(actual, @opts)
                      [d.nil?                                      , :match_matcher, d]
        when Class  ; [actual.is_a?(expected)                         , :match_class  ]
        when Range  ; [expected.include?(actual)                      , :match_range  ]
        when Proc   ; [expected.call(actual)                          , :match_proc   ]
        when Regexp ; [actual.is_a?(String) && actual.match(expected) , :match_regexp ]
        else          [actual == expected                             , :match_value  ]
      end
    end

    def items_to_s(expected, items)
      case expected
        when Hash ; "{\n#{items.join(",\n")}\n}\n"
        when Array; "[\n#{items.join(",\n")}\n]\n"
        else items.join.strip
      end if items.size > 0
    end

    def match_regexp_to_s(expected, actual)
      if actual.is_a? String
        color, prefix = @color_scheme[:match_regexp]
        actual.sub(expected, "#{color}(\e[1m#{actual[expected, 0]}#{RESET}#{color})#{RESET}")
      end
    end

    def match_to_s(expected, actual, match_type)
      actual = match_regexp_to_s(expected, actual) if match_type == :match_regexp
      markup(match_type, actual) if matches_shown.include?(match_type)
    end

    def difference_to_s(expected, actual)
      match, match_type, d = match?(expected, actual)
      if match
        match_to_s(expected, actual.inspect, match_type)
      else
        match_type == :match_matcher ? d :
          "#{markup(:missing, expected.inspect)}#{markup(:additional, actual.inspect)}"
      end
    end

    def markup(item_type, item)
      if item_type == :different
        item.split("\n").map {|line| "  #{line}"}.join("\n") if item
      else
        color, prefix = @color_scheme[item_type]
        "#{color}#{prefix+' ' if prefix}#{BOLD if color and item_type != :match_regexp}#{RESET if item_type == :match_regexp}#{item}#{RESET if color}" if item
      end if item
    end
  end
end
