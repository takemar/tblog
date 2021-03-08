# frozen_string_literal: true

require 'delegate'
require 'forwardable'
require 'active_support/core_ext/class/attribute'
require_relative 'models'

module TakemaroBlog; module View

  module Helper
    def config
      TakemaroBlog.config
    end

    def url(path)
      if @app.respond_to?(:path2url)
        @app.path2url(path)
      else
        "/#{ path }"
      end
    end

    def stylesheets
      ['css/normalize.css', 'css/common.css'].map(&method(:url))
    end

    def scripts
      []
    end

    def meta_title
      "#{ title } - #{ config.blog_meta_title }"
    end

    def share_title
      "#{ title } - #{ config.blog_share_title }"
    end
  end

  class ArchiveBase
    include Helper
    extend Forwardable

    class_attribute :template, instance_writer: false, instance_predicate: false
    private :template

    def initialize(webdir, webdir_list, webdir_item)
      @webdir = webdir
      @webdir_list = webdir_list
      @webdir_item = webdir_item
    end

    def render(app)
      @app = app
      app.haml template, { views: "#{ app.settings.root }/templates", scope: self } do |posts|
        app.haml :posts, {
          views: "#{ app.settings.root }/templates", scope: self, locals: { posts: posts }, layout: false
        }
      end
    end

    def path
      @path ||= @webdir_list.path_of(@webdir_item)
    end

    private

      def prev
        if defined? @prev then @prev else @prev = @webdir_list.prev_of(@webdir_item) end
      end

      def succ
        if defined? @succ then @succ else @succ = @webdir_list.succ_of(@webdir_item) end
      end

      alias next succ
  end

  class Year < ArchiveBase
    def_delegator :@webdir_item, :year

    self.template = :year

    def render(app)
      @app = app
      app.haml template, { views: "#{ app.settings.root }/templates", scope: self }
    end

    def months
      @months ||= @webdir.months_html.to_a.select do |item|
        year == item.year
      end
    end

    def archived_tags
      @archived_tags ||= @webdir.tags_by_year[year].to_a
    end

    def title
      "アーカイブ：#{ year }年"
    end
  end

  class Month < ArchiveBase
    def_delegators :@webdir_item, :year, :month

    self.template = :month

    def posts
      @posts ||= Post.where(created_at: Time.zone.local(year, month).all_month).order(created_at: :desc)
    end

    def title
      "アーカイブ：#{ year }年#{ month }月"
    end
  end

  class TagArchive < ArchiveBase
    def_delegator :@webdir_list, :tag
    def_delegator :@webdir_item, :year

    self.template = :tag_archive

    def posts
      @posts ||= tag.get_posts.where(created_at: Time.zone.local(year).all_year).order(created_at: :desc)
    end

    def title
      "タグ：#{ tag.name } #{ year }年"
    end
  end

  class Root < ArchiveBase
    self.template = :root

    def initialize(*args)
    end

    def render(app)
      @app = app
      app.haml :root, { views: "#{ app.settings.root }/templates", scope: self, layout: false } do |posts|
        app.haml :posts, {
          views: "#{ app.settings.root }/templates", scope: self, locals: { posts: posts }, layout: false
        }
      end
    end

    def posts
      Post.order(created_at: :desc).limit(32)
    end

    def tags
      Tag.ordered_all
    end

    def path
      @path ||= ''
    end

    def meta_title
      config.blog_root_meta_title
    end

    def share_title
      config.blog_root_share_title
    end
  end

  class Archive < ArchiveBase
    attr_reader :years, :months_by_year

    self.template = :archive

    def initialize(years_list, months_list)
      @years = years_list.to_a.map(&:to_i)
      @months_by_year = months_list.to_a.group_by(&:year).map {|k, v| [k, v.map(&:month)] }.to_h
    end

    def path
      'posts/'
    end

    def title
      'アーカイブ'
    end
  end

  class Tags < ArchiveBase
    attr_reader :tag_years

    self.template = :tags

    def initialize(tag_years_list)
      @tag_years = tags.map do |tag|
        [tag.slug, tag_years_list[tag.slug].to_a.map(&:to_i)]
      end.to_h
    end

    def tags
      Tag.ordered_all
    end

    def path
      'tags/'
    end

    def title
      'タグ'
    end
  end

  class PostView < DelegateClass(Post)
    extend Forwardable
    include Helper

    def_delegator :@footnotes, :add, :footnote
    attr_reader :footnotes

    def render(app)
      @app = app
      app.haml :post, { views: "#{ app.settings.root }/templates", scope: self } do render_body end
    end

    def render_body(app = @app)
      return @rendered_body if @rendered_body
      @app = app
      @footnotes = Footnotes.new(app, self)
      @rendered_body = case format
        when 'html' then text
        else app.send format, text, { scope: self, layout: false }
        end.each_line.map(&:strip).reject(&:empty?).join("\n")
    end

    def path
      @path ||= "posts/#{ created_at.strftime '%Y/%m/%d' }-#{ slug }"
    end

    def stylesheets
      [
        'css/normalize.css',
        ('css/prism-solarizedlight.css' if has_asset?('syntaxhighlight')),
        'css/common.css',
        (created_at.strftime "css/single/%Y%m%d-#{ slug }.css" if has_asset?('single-css')),
      ].compact.map(&method(:url))
    end

    def scripts
      scripts = []
      if has_asset?('single-js')
        scripts << {src: url(created_at.strftime("js/single/%Y%m%d-#{ slug }.js")), defer: true}
      end
      if has_asset?('footnote')
        scripts << {src: url('js/footnote.js'), defer: true}
      end
      scripts << {src: 'https://platform.twitter.com/widgets.js', async: true, charset: 'utf-8'}
    end

    def img(filename, alt)
      imgpath = url("files/#{ created_at.strftime '%Y%m%d' }-#{ slug }/#{ filename }")
      %!<a class="img-container" href="#{ imgpath }" target="_blank"><img alt="#{ alt }" src="#{ imgpath }"></a>!
    end

    class Footnotes
      def initialize(app, view)
        @app = app
        @view = view
      end

      def add(label, text, format = :html)
        @list ||= []
        @list << { label: label, text: case format when :html then text else send format, text, { scope: @view, layout: false } end }
        @app.haml(<<~'EOT', { scope: @view, layout: false }, { label: label, list: @list }).strip
          %span.footnote-link-wrapper<
            %a.footnote-link{id: "footnote-anchor-#{ label }",href: "#footnote-#{ label }", data: {footnote: label}}= list.length 
        EOT
      end

      def any?
        !!@list
      end

      def render
        return unless @list
        @app.haml(<<~'EOT', { scope: @view, layout: false }, { list: @list }).strip
          .footnotes
            %hr
            %ol
              - list.each_with_index do |f, i|
                %li{id: "footnote-#{ f[:label] }"}
                  %span.footnote-counter<
                    %a{href: "#footnote-anchor-#{ f[:label] }"}>= i + 1
                    = '.'
                  != f[:text].strip
        EOT
      end
    end
  end

  class TagView < DelegateClass(Tag)
    include Helper

    attr_reader :years

    def initialize(tag, years_list)
      super(tag)
      @years = years_list.to_a.map(&:to_i)
    end

    def render(app)
      @app = app
      app.haml :tag, { views: "#{ app.settings.root }/templates", scope: self } do |posts|
        app.haml :posts, {
          views: "#{ app.settings.root }/templates", scope: self, locals: { posts: posts }, layout: false
        }
      end
    end

    def path
      @path ||= "tags/#{ slug }"
    end

    def title
      "タグ：#{ name }"
    end
  end

end; end
