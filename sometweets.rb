$KCODE = 'u'
require 'rubygems'
require 'activerecord'
dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig['production']

require 'cgi'
require 'twitter'
require 'oauth'
require 'sinatra'
require 'partials'
require 'simple_proxy'

set :environment, :production
set :lock, false
set :static, true
set :sessions, true

SERVE_CONTENT = nil

helpers do
  include Sinatra::Partials
end

use SimpleProxy do |request|
  case request.path 
  when %r[^/(search|trends)]
    "search.twitter.com"
  when %r[^/(admin|misc|$)]
    SERVE_CONTENT
  else
    "twitter.com"
  end
end

get "/" do
  erb :home
end

def oauth
  unless ENV["OAUTH_TOKEN"] &&  ENV["OAUTH_SECRET"]
    throw :halt, [ 401, 'Need OAUTH_TOKEN and OAUTH_SECRET for your app!' ]
  end
  Twitter::OAuth.new(ENV["OAUTH_TOKEN"], ENV["OAUTH_SECRET"])
end

def token
  if session[:token] && session[:secret]
    puts "Recalling token: #{session[:token]}"
    OAuth::RequestToken.new(oauth.consumer, session[:token], session[:secret])
  else
    t = oauth.consumer.get_request_token(:oauth_callback => "http://twitter.local/admin")
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
    redirect "/admin" and return
  end
  if client = logged_in_client
    @timeline = client.home_timeline
    @favs = client.favorites
    erb :admin
  else
    redirect token.authorize_url
  end
end