# frozen_string_literal: true

require 'active_record'

ActiveRecord::Tasks::DatabaseTasks.env = ENV['APP_ENV'] || 'default'
ActiveRecord::Tasks::DatabaseTasks.database_configuration = YAML.load_file(File.expand_path('../config/database.yml', __FILE__))
ActiveRecord::Tasks::DatabaseTasks.root = File.expand_path(File.dirname(__FILE__))
ActiveRecord::Tasks::DatabaseTasks.db_dir = File.expand_path('../db', __FILE__)
ActiveRecord::Tasks::DatabaseTasks.migrations_paths = File.expand_path('../db/migrate', __FILE__)
ActiveRecord::Tasks::DatabaseTasks.seed_loader = Class.new do
  def load_seed
    load File.expand_path('../db/seeds.rb', __FILE__)
  end
end.new

task :environment do
  ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration
  ActiveRecord::Base.establish_connection(ActiveRecord::Tasks::DatabaseTasks.env.to_sym)
end

load 'active_record/railties/databases.rake'

task :boot do
  require_relative 'app/boot'
end

task console: :boot do
  require 'pry'
  TakemaroBlog::Application.new!.instance_eval do
    with_sftp do |sftp|
      webdir = TakemaroBlog::Webdir.new(self, sftp)
      binding.pry
    end
  end
end
