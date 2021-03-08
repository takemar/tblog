# frozen_string_literal: true

require 'forwardable'
require 'securerandom'
require 'sinatra/base'
require 'hamlit'
require 'redcarpet'
require 'active_record'
require 'active_support/core_ext/module/attribute_accessors'

module TakemaroBlog; end

class TakemaroBlog::Post < ActiveRecord::Base
  extend Forwardable

  has_and_belongs_to_many :tags
  has_many :assets

  attr_reader :content, :raw_content
  cattr_accessor :source_dir
  def_delegators :view, :render, :render_body, :path

  before_create do
    self.source = SecureRandom.hex
    File.write "#{ source_dir }/#{ self.source }", @text
  end

  def view
    @view ||= TakemaroBlog::View::PostView.new(self)
  end

  def text
    @text ||= File.read "#{ source_dir }/#{ self.source }"
  end

  attr_writer :text

  def has_asset?(name)
    @asset_names ||= assets.map(&:name)
    @asset_names.include?(name)
  end

  def prev(tag = nil)
    prev_succ :prev, tag
  end

  def succ(tag = nil)
    prev_succ :succ, tag
  end

  alias next succ

  private def prev_succ(which, tag)
    unless tag
      self.class.includes(:tags, :assets)
    else
      self.class.includes(:tags, :assets).joins(:tags).where('tags.id': tag.id)
    end
      .where("posts.created_at #{
        case which
        when :prev then '<'
        when :succ then '>'
        end
      } ?", created_at).order(created_at:
        case which
        when :prev then :desc
        when :succ then :asc
        end
      ).first
  end

  class << self
    def oldest
      @@oldest ||= order(created_at: :asc).first
    end

    def latest
      @@latest ||= order(created_at: :desc).first
    end
  end

  after_save do
    @@oldest, @@latest = nil
  end
end

class TakemaroBlog::Tag < ActiveRecord::Base
  extend Forwardable

  has_and_belongs_to_many :posts

  #def_delegators :view, :render, :path

  #def view
  #  @view ||= TakemaroBlog::View::TagView.new(self)
  #end

  def path
    @path ||= "tags/#{ slug }"
  end

  def recent_posts
    get_posts.order(created_at: :desc).limit(32)
  end

  def get_posts
    Post.joins(:tags).where('tags.id': id)
  end

  class << self
    def ordered_all
      @@ordered_all ||= order(order: :desc, updated_at: :asc)
    end
  end

  after_save do
    @@ordered_all = nil
  end
end

class TakemaroBlog::Asset < ActiveRecord::Base
  belongs_to :post
end

Post = TakemaroBlog::Post
Tag = TakemaroBlog::Tag
