# frozen_string_literal: true

require 'yaml'
require 'active_record'

ActiveRecord::Base.establish_connection(
  YAML.load_file(File.expand_path('../../config/database.yml', __FILE__))[ENV['APP_ENV'] || 'default']
)

require_relative 'blog'
require_relative '../config/application'
