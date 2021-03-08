# frozen_string_literal: true

require 'active_support/core_ext/class/attribute'

module TakemaroBlog; class Webdir

  class Item
    def self.try_convert(*args)
      if args.first.kind_of? self
        args.first
      else
        self.new *args
      end
    end

    def initialize
      raise NotImplementedError
    end

    def ===(other)
      self.content == self.class.try_convert(other).content
    end

    def eql?(other)
      other.kind_of?(self.class) && (self.content).eql?(other.content)
    end

    alias == eql?

    def <=>(other)
      self.content <=> other.content if other.kind_of?(self.class)
    end

    def hash
      self.content.hash
    end

    def to_s
      self.content.to_s
    end
  end

  class Year < Item
    attr_reader :year

    def initialize(arg)
      @year = case arg when Time then arg.year else arg.to_i end
    end

    def to_i
      @year
    end

    def to_a
      [@year.to_s]
    end

    alias content to_i
    protected :content
  end

  class Month < Item
    attr_reader :year, :month

    def initialize(arg, month = nil)
      @year, @month = 
        case arg
        when Time then [arg.year, arg.month]
        when Array then arg.map(&:to_i)
        else [arg.to_i, month.to_i]
        end
    end

    def to_a
      [@year.to_s, @month.to_s.rjust(2, '0')]
    end

    protected def content
      [@year, @month]
    end
  end

end; end
