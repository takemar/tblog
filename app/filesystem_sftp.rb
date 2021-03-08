# frozen_string_literal: true

require 'net/sftp'
require 'pathname'

module TakemaroBlog; module Filesystem; end; end

class TakemaroBlog::Filesystem::SFTP
  def initialize(config, renderer)
    @config = config
    @renderer = renderer
  end

  def close
    if @session
      @session.loop
      @session.session.close
    end
  end

  def mkdir(dir)
    session.mkdir!((sftp_root + dir).to_s)
  end

  def mkfile(arg, app)
    session.open remote_file(arg.path), 'w' do |res|
      session.write res[:handle], 0, arg.render(app)
    end
  end

  def glob(path, pattern)
    directory = pattern.end_with? '/'
    pattern = pattern.chop if directory
    result = session.dir.glob((sftp_root + path).to_s, pattern)
    result.select!(&:directory?) if directory
    result.map(&:name)
  end

  private

    def session
      @session ||= Net::SFTP.start @config.sftp_host, @config.sftp_user, (@config.sftp_option || {})
    end

    def remote_file(path)
      (sftp_root + "#{ path }#{
        'index' if path.end_with?('/') || path.empty? 
      }#{
        '.html' unless path.end_with?('.html')
      }").to_s
    end

    def sftp_root
      @sftp_root ||= Pathname.new(@config.sftp_root)
    end

end
