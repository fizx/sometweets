require 'sinatra'
 
set :environment, :production
set :run, false
set :lock, false
set :static, true
 
require File.dirname(__FILE__) + '/sometweets'
run Sinatra::Application