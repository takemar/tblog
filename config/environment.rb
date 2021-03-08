# frozen_string_literal: true

TakemaroBlog.config.merge!(
  auth: {
    # Rack::Auth::Digest::MD5 に渡される
    'username' => '0665fcae289dda92188f71c03828220b'
  },
  # SFTPの認証情報は ~/.ssh/config の情報が使われる
  sftp_host: 'blog.example.com',
  sftp_user: 'example',
  sftp_root: '/path/to/www/root',
  blog_heading_title: 'My Example Blog',
  blog_meta_title: 'My Example Blog',
  blog_share_title: 'My Example Blog',
  blog_root_meta_title: 'My Example Blog',
  blog_root_share_title: 'My Example Blog,
  blog_domain: 'blog.example.com',
  blog_scheme: 'https',
)

TakemaroBlog::Post.source_dir = File.expand_path('../../files/source/', __FILE__)
