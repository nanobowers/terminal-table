# coding: utf-8
require 'forwardable'

module Terminal
  class Table

    class Border
      attr_accessor :data
      def []=(key, val)
        @data[key] = val
      end
      def [](key)
        @data[key]
      end
      def initialize_dup(other)
        super
        @data = other.data.dup
      end
      def remove_verticals 
        self.class.const_get("VERTICALS").each { |key| @data[key] = "" }
        self.class.const_get("INTERSECTIONS").each { |key| @data[key] = "" }
      end
      def remove_horizontals 
        self.class.const_get("HORIZONTALS").each { |key| @data[key] = "" }
      end
    end
    
    class AsciiBorder < Border
      HORIZONTALS = %i[x]
      VERTICALS = %i[y]
      INTERSECTIONS = %i[i]
      
      def initialize
        @data = { x: "-", y: "|", i:  "+" }
      end
      
      # Get vertical border elements
      # @return [Array] 3-element list of [left, center, right]
      def vertical
        y = @data[:y]
        [y, y, y] # left, center, right
      end
      
      # Get horizontal border elements
      # @return [Array] a 6 element list of: [i-left, horizontal-bar, i-up/down, i-right, i-down, i-up]
      def horizontal(_type)
        x, i = @data[:x], @data[:i]
        [i, x, i, i, i, i]
      end
    end
    
    class UnicodeBorder < Border
      HORIZONTALS = %i[x sx hx nx]
      VERTICALS = %i[y yw ye]
      INTERSECTIONS = %i[nw n ne nd 
                         hw hi he hd hu
                         w i e dn up 
                         sw s se su]
      def initialize 
        @data = {
          nw: "┌", nx: "─", n:  "┬", ne: "┐",
          yw: "│",          y:  "│", ye: "│", 
          hw: "╞", hx: "═", hi: "╪", he: "╡", hd: '╤', hu: "╧",
          w:  "├", x:  "─", i:  "┼", e:  "┤", dn: "┬", up: "┴",
          sw: "└", sx: "─", s:  "┴", se: "┘",
        }
      end
      # Get vertical border elements
      # @return [Array] 3-element list of [left, center, right]
      def vertical
        [@data[:yw], @data[:y], @data[:ye]] 
      end

      # Get horizontal border elements
      # @return [Array] a 6 element list of: [i-left, horizontal-bar, i-up/down, i-right, i-down, i-up]
      def horizontal(type)
        case type
        when :below_heading
          [@data[:hw], @data[:hx], @data[:hi], @data[:he], @data[:hd], @data[:hu] ]
        when :top
          [@data[:nw], @data[:nx], @data[:n], @data[:ne], @data[:n], nil ]
        when :bot
          [@data[:sw], @data[:sx], @data[:s], @data[:se], nil, @data[:s] || @data[:up] ]
        else # center
          [@data[:w], @data[:x], @data[:i], @data[:e], @data[:dn], @data[:up] ]
        end
      end
    end

    # Unicode Border With rounded edges
    class UnicodeRoundBorder < UnicodeBorder
      def initialize
        super
        @data.merge!({nw: '╭', ne: '╮', sw: '╰', se: '╯'})
      end
    end

    # Unicode Border with thick outer edges
    class UnicodeThickEdgeBorder < UnicodeBorder
      def initialize
        @data = {
          nw: "┏", nx: "━", n:  "┯", ne: "┓", nd: nil,
          yw: "┃",          y:  "│", ye: "┃", 
          hw: "┣", hx: "═", hi: "╪", he: "┫", hd: '╤', hu: "╧",
          w:  "┠", x:  "─", i:  "┼", e:  "┨", dn: "┬", up: "┴",
          sw: "┗", sx: "━", s:  "┷", se: "┛", su:  nil,
        }
      end
    end
    
    # A Style object holds all the formatting information for a Table object
    #
    # To create a table with a certain style, use either the constructor
    # option <tt>:style</tt>, the Table#style object or the Table#style= method
    #
    # All these examples have the same effect:
    #
    #     # by constructor
    #     @table = Table.new(:style => {:padding_left => 2, :width => 40})
    #
    #     # by object
    #     @table.style.padding_left = 2
    #     @table.style.width = 40
    #
    #     # by method
    #     @table.style = {:padding_left => 2, :width => 40}
    #
    # To set a default style for all tables created afterwards use Style.defaults=
    #
    #     Terminal::Table::Style.defaults = {:width => 80}
    #
    class Style
      extend Forwardable
      def_delegators :@border, :vertical, :horizontal, :remove_verticals, :remove_horizontals
      
      @@defaults = {
        :border => AsciiBorder.new,
        :border_top => true, :border_bottom => true,
        :padding_left => 1, :padding_right => 1,
        :margin_left => '',
        :width => nil, :alignment => nil,
        :all_separators => false,
      }

      ## settors/gettor for legacy ascii borders
      def border_x=(val) ; @border[:x] = val ; end
      def border_y=(val) ; @border[:y] = val ; end
      def border_i=(val) ; @border[:i] = val ; end
      def border_y ; @border[:y] ; end

      # Accessor for instance of Border
      attr_accessor :border
      
      attr_accessor :border_top
      attr_accessor :border_bottom

      attr_accessor :padding_left
      attr_accessor :padding_right

      attr_accessor :margin_left

      attr_accessor :width
      attr_accessor :alignment

      attr_accessor :all_separators

      
      def initialize options = {}
        apply self.class.defaults.merge(options)
      end

      def apply options
        options.each do |m, v|
          __send__ "#{m}=", v
        end
      end
      
      class << self
        def defaults
          klass_defaults = @@defaults.dup
          # border is an object that needs to be duplicated on instantiation,
          # otherwise everything will be referencing the same object-id.
          klass_defaults[:border] = klass_defaults[:border].dup
          return klass_defaults
        end
        
        def defaults= options
          @@defaults = defaults.merge(options)
        end

      end

      def on_change attr
        method_name = :"#{attr}="
        old_method = method method_name
        define_singleton_method(method_name) do |value|
          old_method.call value
          yield attr.to_sym, value
        end
      end
          
    end
  end
end
