require "rubygems" 
require File.dirname(__FILE__) + '/sometweets'
require 'test/unit'
require 'rack/test'

unless ENV["TWITTER_USER"] && ENV["TWITTER_PASSWORD"]
  puts "Please provide the TWITTER_USER and TWITTER_PASSWORD environment variables."
  exit 1
end

set :environment, :test

class FilerTest < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def 
end

dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig['production']