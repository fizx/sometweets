require 'rubygems'
require 'activerecord'
dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig['production']

require 'cgi'
require 'twitter'
require 'oauth'
require 'sinatra'
require 'rack/streaming_proxy'

SERVE_CONTENT = nil

use Rack::StreamingProxy do |request|
  case request.path 
  when %r[^/(search|trends)]
    "http://search.twitter.com/#{request.path}"
  when %r[^/(admin|misc|$)]
    SERVE_CONTENT
  else
    "http://api.twitter.com/#{request.path}"
  end
end

get "/" do
  erb :home
end

def oauth
  Twitter::OAuth.new(ENV["OAUTH_TOKEN"], ENV["OAUTH_SECRET"])
end

def token
  if session[:token] && session[:secret]
    OAuth::RequestToken.new(oauth.consumer, session[:token], session[:secret])
  else
    t = oauth.consumer.get_request_token(:oauth_callback => "http://sometweets.heroku.com/admin")
    session[:token]  = t.token
    session[:secret] = t.secret
    t
  end
end

def login
  return false unless session[:token]
  
  unless session[:access_token]
    access = token.get_access_token
    session[:access_token] = access.token
    session[:access_secret] = access.secret
  end
end

def logged_in_client
  return nil unless session[:token]
  
  unless session[:access_token]
    access = token.get_access_token
    session[:access_token] = access.token
    session[:access_secret] = access.secret
  end

  o = oauth()
  o.authorize_from_access(session[:access_token], session[:access_secret])
  Twitter::Base.new(o)  
end

get "/admin" do
  if client = logged_in_client
    @timeline = client.home_timeline
    erb :admin
  else
    redirect token.authorize_url
  end
end