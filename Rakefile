task :default => :test

task :test do 
  load 'sometweets_test.rb'
end

task :environment do
  require 'sometweets'
end

namespace :db do
  desc "Migrate the database"
  task(:migrate => [:environment]) do
      
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate")
  end
end
