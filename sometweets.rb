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
require 'zlib'
require 'stringio'
require "libxml"

set :environment, :production
set :lock, false
set :static, true
set :sessions, true

SERVE_CONTENT = nil

helpers do
  include Sinatra::Partials
end

class ZippyXMLCallback
  def call(code, headers, content)
    gz = Zlib::GzipReader.new(StringIO.new(content))
    doc = LibXML::XML::Document.io(gz)
    transform(doc)
    buffer = StringIO.new("", "r+")
    writer = Zlib::GzipWriter.new(buffer)
    writer.write(doc.to_s)
    writer.close
    content = buffer.string
    return [code, headers, content]
  end
  
  def transform
    raise "abstract"
  end
end

class FilterCallback < ZippyXMLCallback
  def transform(doc)
    doc.find("//status").each do
      
    end
  end
end

class FavoriteCallback < ZippyXMLCallback
  def initialize(keyword)
    @value = keyword == "create" ? 1 : -1
  end
  
  def transform(doc)
    
  end
end


use SimpleProxy do |request|
  
    puts request.env.inspect
  case request.path 
  when %r[/statuses/home_timeline.xml]
    SERVE_CONTENT#    ["twitter.com", FilterCallback.new()]
  when %r[/favorites/(\w+)/(\d+).xml]
    ["twitter.com", FavoriteCallback.new($1)]
  when %r[^/(search|trends)]
    "search.twitter.com"
  when %r[^/(admin|misc|$)]
    SERVE_CONTENT
  else
    "twitter.com"
  end
end
# /statuses/home_timeline.xml?count=100

get /.*/ do
  puts request.env.inspect
  "huh"
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