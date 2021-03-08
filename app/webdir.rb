# frozen_string_literal: true

require 'forwardable'
require_relative 'view'
require_relative 'webdir_list'
require_relative 'webdir_objects'

module TakemaroBlog; end

class TakemaroBlog::Webdir
  include TakemaroBlog
  extend Forwardable

  def_delegators :@fs, :mkfile, :mkdir

  def initialize(app, fs)
    @app = app
    @fs = fs
  end

  def add_post(post)
    time = post.created_at
    years_dir.add_or_update time
    months_dir.add_or_update time
    mkfile post, post.prev, post.next
    archive_updated = months_html.add_or_update time
    tag_updated = post.tags.map do |tag|
      tags_dir.add_or_update tag.slug
      result = tag_years_html[tag].add_or_update time
      mkfile View::TagView.new(tag, tag_years_html[tag]), post.prev(tag), post.next(tag)
      result
    end.any?
    years_html.add_or_update time
    if tag_updated
      mkfile View::Tags.new(tag_years_html)
    end
    if archive_updated
      mkfile View::Archive.new(years_html, months_html)
    end
    mkfile View::Root.new
  end

  def mkfile(*args)
    args.compact.each do |arg|
      @fs.mkfile arg, @app
    end
  end

  def glob(dir, pattern)
    @fs.glob(dir, pattern).map do |path|
      path.match(pattern.delete_suffix('/').split('*', -1).map {|s| Regexp.escape(s) }.join('(.*)')).captures
    end
  end

  [:years_dir, :years_html, :months_dir, :months_html, :tags_dir].each do |name|
    define_method name do
      variable_name = "@#{ name }".to_sym
      unless instance_variable_defined? variable_name
        instance_variable_set variable_name, List.new(name, self)
      else
        instance_variable_get variable_name
      end
    end
  end

  def tag_years_html
    @tag_years_html ||= Hash.new do |hash, key|
      tag, slug = if key.is_a?(Tag) then [key, key.slug] else [nil, key] end
      next hash[slug] if hash.has_key?(slug)
      tag = Tag.find_by(slug: slug) unless tag
      hash[slug] = List.new(:tag_years_html, tag, self)
    end
  end

  def tags_by_year
    @tags_by_year ||= Hash.new do |hash, year|
      hash[year] = List.new(:tags_by_year, year, self)
    end
  end

end
