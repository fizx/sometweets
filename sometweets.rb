require 'rubygems'
require 'activerecord'
dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig['production']

require 'cgi'
require 'twitter'
require 'oauth'
require 'sinatra'
require 'rack/streaming_proxy'

set :environment, :production
set :lock, false
set :static, true
set :sessions, true

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
  unless ENV["OAUTH_TOKEN"] &&  ENV["OAUTH_SECRET"]
    puts "Need OAUTH_TOKEN and OAUTH_SECRET for your app!"
    exit 1
  end
  Twitter::OAuth.new(ENV["OAUTH_TOKEN"], ENV["OAUTH_SECRET"])
end

def token
  if session[:token] && session[:secret]
    puts "Recalling token: #{session[:token]}"
    OAuth::RequestToken.new(oauth.consumer, session[:token], session[:secret])
  else
    t = oauth.consumer.get_request_token(:oauth_callback => "http://sometweets.heroku.com/admin")
    session[:token]  = t.token
    session[:secret] = t.secret
    puts "Generated token: #{session[:token]} (#{t.token})"
    puts "Session(setting): #{session.inspect}"
    t
  end
end

def logged_in_client
  return nil unless session[:access_token]

  o = oauth()
  o.authorize_from_access(session[:access_token], session[:access_secret])
  Twitter::Base.new(o)  
end

get "/admin/logout" do
  session.clear
  redirect "/"
end

get "/admin" do
  puts "Session(/admin): #{session.inspect}"
  if params[:oauth_verifier]
    puts "Asking token: #{session[:token]} with verifier: #{params[:oauth_verifier]} for access token"
    access = token.get_access_token(:oauth_verifier => params[:oauth_verifier])
    session[:access_token] = access.token
    session[:access_secret] = access.secret
  end
  # session[:access_secret] ||= params[:oauth_verifier]
  if client = logged_in_client
    @timeline = client.home_timeline
    erb :admin
  else
    redirect token.authorize_url
  end
end