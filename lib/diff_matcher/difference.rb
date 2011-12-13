module DiffMatcher

  def self.difference(expected, actual, opts={})
    difference = Difference.new(expected, actual, opts)
    difference.matching? ? nil : difference.to_s
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

    COLOR_SCHEMES = {
      :default=>{
        :missing       => [RED   , "-"],
        :additional    => [YELLOW, "+"],
        :match_value   => [RESET , " "],
        :match_regexp  => [GREEN , "~"],
        :match_class   => [BLUE  , ":"],
        :match_proc    => [CYAN  , "{"]
      },
      :white_background=> {
        :missing       => [RED    , "-"],
        :additional    => [MAGENTA, "+"],
        :match_value   => [RESET  , " "],
        :match_regexp  => [GREEN  , "~"],
        :match_class   => [BLUE   , ":"],
        :match_proc    => [CYAN   , "{"]
      }
    }

    attr_reader :dif

    def initialize(expected, actual, opts={})
      @ignore_additional = opts[:ignore_additional]
      @quiet             = opts[:quiet]
      @color_enabled     = opts[:color_enabled] || !!opts[:color_scheme]
      @color_scheme      = COLOR_SCHEMES[opts[:color_scheme] || :default]
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
            "#{color}#{prefix} #{BOLD}#{count} #{item_type}#{RESET}" if count > 0
          end
        }.compact.join(", ")
        msg <<  "\nWhere, #{where}" if where.size > 0

        @color_enabled ? msg : msg.gsub(/\e\[\d+m/, "")
      end
    end

    private

    def item_types
      @item_types ||= @ignore_additional ? [:missing] : [:missing, :additional]
    end

    def matches_shown
      @matches_shown ||= lambda {
        ret = []
        unless @quiet
          ret += [:match_class, :match_proc, :match_regexp]
          ret += [:match_value]
        end
        ret
      }.call
    end

    def difference(expected, actual, reverse=false)
      if actual.is_a? expected.class
        left = diff(expected, actual, true)
        right = diff(actual, expected)
        items_to_s(
          expected,
          [:different, :missing, :additional].inject([]) { |a, method|
            a + send(method, left, right, expected.class).compact.map { |item| markup(method, item) }
          }
        )
      else
        difference_to_s(expected, actual, reverse)
      end
    end

    def diff(expected, actual, reverse=false)
      if expected.is_a?(Hash)
        expected.keys.inject({}) { |h, k|
          h.update(k => actual.has_key?(k) ? difference(actual[k], expected[k], reverse) : expected[k])
        }
      elsif expected.is_a?(Array)
        expected, actual = [expected, actual].permutation.map { |a, b|
          Diff::LCS.sdiff(b, a).map(&:new_element).each_with_index.inject({}) { |h,(x,i)| h.update(i=>(x||:___null)) }
        }
        diff(expected, actual)
      else
        actual
      end if expected.is_a? actual.class
    end

    def compare(right, expected_class, default=nil)
      if [Hash, Array].include? expected_class
        right && right.keys.tap { |keys| keys.sort if expected_class == Array }.map { |k|
          yield k
        }
      else
        [default]
      end
    end

    def different(left, right, expected_class)
      compare(right, expected_class, difference_to_s(right, left)) { |k|
        if right[k] and left.has_key?(k)
          pad = %w([ {).include?(right[k][0]) ? "" : "  " # pad unless value is a Hash or Array difference
          result = "#{"#{pad}#{k.inspect}=>" if expected_class == Hash}#{right[k]}"
          result.scan("\n").size > 0 ? indent(result) : result
        end
      }
    end

    def missing(left, right, expected_class)
      compare(left, expected_class) { |k|
        "#{"#{k.inspect}=>" if expected_class == Hash}  #{left[k]}" unless right.has_key?(k)
      }
    end

    def additional(left, right, expected_class)
      missing(right, left, expected_class)
    end

    def match?(expected, actual)
      case expected
        when Class ; [actual.is_a?(expected)                         , :match_class  ]
        when Proc  ; [expected.call(actual)                          , :match_proc   ]
        when Regexp; [actual.is_a?(String) && actual.match(expected) , :match_regexp ]
        else         [actual == expected                             , :match_value  ]
      end
    end

    def indent(str, n=2)
      (" "*n)+str.split("\n").join("\n#{" "*n}")
    end

    def items_to_s(expected, items)
      case expected
        when Hash ; "{\n#{items.join(",\n")}\n}\n"
        when Array; "[\n#{items.join(",\n")}\n]\n"
        else items.join#.strip
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
      markup(match_type, actual) if matches_shown.include?(match_type) # XXX is this called?
    end

    def difference_to_s(expected, actual, reverse=false)
      match, match_type = match?(*(reverse ? [actual, expected] : [expected, actual]))
      if match
        match_to_s(expected, actual, match_type)
      else
        if   actual    == :___null
          "#{markup(:missing, expected.inspect)}"
        elsif expected == :___null
          "#{markup(:additional, actual.inspect)}" unless @quiet
        else
          "#{markup(:missing, expected.inspect)}#{markup(:additional, actual.inspect)}"
        end
      end
    end

    def markup(item_type, item)#, left=nil, right=nil)
      if item_type == :different
        item
      else
        color, prefix = @color_scheme[item_type]
        "#{color}#{prefix} #{BOLD if color and item_type != :match_regexp}#{RESET if item_type == :match_regexp}#{item}#{RESET if color}" if item
      end if item
    end
  end
end
