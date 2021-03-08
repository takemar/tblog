# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/reloader'
require 'hamlit'
require 'active_support/core_ext/time'
require 'active_support/ordered_options'
require_relative 'filesystem_sftp'
require_relative 'models'
require_relative 'response_helper'
require_relative 'webdir'

module TakemaroBlog
  def self.config
    @@config ||= ActiveSupport::OrderedOptions.new
  end
end

module TakemaroBlog; class Application < Sinatra::Application
  register Sinatra::Namespace
  register Sinatra::Reloader

  include TakemaroBlog
  include TakemaroBlog::ResponseHelper

  use Rack::Auth::Digest::MD5, realm: '', opaque: '', passwords_hashed: true do |username|
    config.auth[username]
  end

  configure do
    set :app_file, __FILE__
    set :haml, attr_quote: '"'
    set :markdown, {
      tables: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      link_attributes: {target: '_blank'},
    }
  end

  before do
    request.params.each {|_, val| Array(val).each {|v| v.gsub!(/\r\n|\r/, "\n") }}
  end

  namespace '/blog' do
    get '/new' do
      haml :new
    end

    post '/new' do
      class << self
        def path2url(path)
          "#{ config.blog_scheme }://#{ config.blog_domain }/#{ path }"
        end
      end
      @post = Post.new(request.params.merge(
        'slug' => request.params['slug'].downcase.gsub(' ', '-'),
        'tags' => converted_tags,
        'assets' => (request.params['assets'] || []).map {|n| Asset.new(name: n) }
      )) {|obj| obj.created_at = current }
      @html = @post.render(self)
      @compiled_source = @post.render_body(self)
      haml :new
    end

    post '/create' do
      with_sftp do |sftp|
        webdir = Webdir.new(self, sftp)
        webdir.add_post(post)
      end
      redirect "#{ config.blog_scheme }://#{ config.blog_domain }/#{ post.path }"
    end
  end

  def self.config
    TakemaroBlog.config
  end

  def config
    TakemaroBlog.config
  end

  private def with_sftp
    sftp = Filesystem::SFTP.new config, self
    result = yield sftp
    sftp.close
    result
  end

  def post
    @post ||= Post.create!(request.params.merge(
      'slug' => request.params['slug'].downcase.gsub(' ', '-'),
      'tags' => converted_tags,
      'assets' => (request.params['assets'] || []).map {|n| Asset.new(name: n) }
    )).tap {|this| @current = this.created_at }
  end

  def converted_tags
    Tag.ordered_all.select {|t| request.params['tags'].include? t.slug }
  end

  def current
    @current ||= Time.current
  end
end; end
