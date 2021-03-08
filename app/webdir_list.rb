# frozen_string_literal: true

require 'delegate'
require 'forwardable'
require 'active_support/core_ext/class/attribute'
require 'active_support/ordered_options'
require_relative 'view'

module TakemaroBlog; class Webdir

  class List < Delegator
    extend Forwardable

    Options = Struct.new(:glob_dir, :path_pattern, :item_class)

    @@subclasses = {}
    class_attribute :options, instance_writer: false, instance_predicate: false
    def_delegators :options, :glob_dir, :path_pattern, :item_class
    def_delegator :@webdir, :glob
    private :options, :glob_dir, :path_pattern, :item_class, :glob

    def self.[](*args, &blk)
      @@subclasses[args] ||= 
        Class.new(self) do |klass|
          klass.subclass_initialize(*args, &blk)
        end
    end

    def self.new(type, optional = nil, webdir)
      case type
      when :years_dir then DirList['posts/', '*/', Year]
      when :years_html then FileList['posts/', '*/index.html', Year, View::Year]
      when :months_dir then DirList['posts/', '*/*/', Month]
      when :months_html then FileList['posts/', '*/*/index.html', Month, View::Month]
      when :tags_dir then DirList['tags/', '*/', String]
      when :tag_years_html then TagArchiveList
      when :tags_by_year then TagListByYear
      end.new(*[webdir, optional].compact)
    end

    def self.inherited(subclass)
      [:new, :inherited].each do |name|
        subclass.define_singleton_method name, Class.instance_method(name)
      end
    end

    def self.subclass_initialize(*args)
      self.options = self::Options.new(*args)
    end
    class << self; protected :subclass_initialize; end

    def initialize(webdir)
      @webdir = webdir
    end

    private def __getobj__
      @obj ||= glob(glob_dir, path_pattern).map {|item| item_class.new(*item) }.sort
    end

    alias array __getobj__
    private :array

    def to_a
      array.dup
    end

    def exist?(arg)
      array.any? {|item| item === arg }
    end

    def add(arg)
      item = item_class.try_convert arg
      raise if array.include? item
      array << item
      array.sort
      add_to_filesystem(item)
    end

    def add_to_filesystem(item)
      raise NotImplementedError, "#{ List } is abstract class. Use #{ DirList } or #{ FileList } instead."
    end

    def update(arg)
      raise NotImplementedError, "#{ List } is abstract class. Use #{ DirList } or #{ FileList } instead."
    end

    def add_or_update(arg)
      if exist? arg then update arg; false else add arg; true end
    end

    def prev_of(arg)
      item = item_class.try_convert arg
      idx = array.index(item)
      array[idx - 1] if idx && idx != 0
    end

    def succ_of(arg)
      item = item_class.try_convert arg
      idx = array.index(item)
      array[idx + 1] if idx
    end

    alias next_of succ_of

    def path_of(item)
      enumerator = Array[*item].each
      path = path_pattern.gsub('*') {|_| enumerator.next }
      "#{ glob_dir }#{ path }"
    end
  end

  class DirList < List
    def_delegator :@webdir, :mkdir
    private :mkdir

    private def add_to_filesystem(item)
      mkdir path_of(item)
    end

    def update(arg)
      # do nothing.
    end
  end

  class FileList < List
    class_attribute :view_class, instance_writer: false, instance_predicate: false
    def_delegator :@webdir, :mkfile
    private :mkfile

    def self.subclass_initialize(*args, view_class)
      self.view_class = view_class
      super(*args)
    end
    class << self; protected :subclass_initialize; end

    private def add_to_filesystem(item)
      [item, prev_of(item), succ_of(item)].compact.each(&method(:update))
    end

    def update(arg)
      mkfile view_class.new(@webdir, self, item_class.try_convert(arg))
    end
  end

  class TagArchiveList < FileList
    attr_reader :tag

    def initialize(webdir, tag)
      @webdir = webdir
      @tag = tag
    end

    private

      def glob_dir
        @glob_dir ||= "tags/#{ @tag.slug }/"
      end

      def path_pattern
        '*.html'
      end

      def item_class
        Year
      end

      def view_class
        View::TagArchive
      end
  end

  # FIXME: tag_yearsでファイルシステムに更新が加えられると、こちらは追従しないので事故る
  class TagListByYear < FileList
    def initialize(webdir, year)
      @webdir = webdir
      @year = year.to_i
    end

    private

      def glob_dir
        @glob_dir ||= "tags/"
      end

      def path_pattern
        "*/#{ @year }.html"
      end

      def item_class
        String
      end

      def view_class
        raise NotImplementedError
      end
  end

end; end
