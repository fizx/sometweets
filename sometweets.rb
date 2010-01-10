$KCODE = 'u'
require 'rubygems'
require 'activerecord'
dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig['production']

require 'cgi'
require 'twitter'
require 'bishop'
require 'oauth'
require 'sinatra'
require 'partials'
require 'simple_proxy'
require 'zlib'
require 'stringio'
require "libxml"
require "base64"

set :environment, :production
set :lock, false
set :static, true
set :sessions, true

SERVE_CONTENT = nil

helpers do
  include Sinatra::Partials
end

class ZippyXMLCallback
  
  def initialize(request)
    encoded = request.env["HTTP_AUTHORIZATION"][/Basic (.*)/, 1]
    handle = Base64.decode64(encoded).split(":").first
    @user = User.find_or_create_by_handle(handle)
  end
  
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

class User < ActiveRecord::Base
  has_many :votes
  
  def update_classifier
    reload
    c = Bishop::Bayes.new { |probs,ignore| Bishop::robinson( probs, ignore ) }
    votes.each do |vote|
      c.train((vote.value > 0 ? "good" : "bad"), prep(vote.speaker_handle, vote.content))
    end
    self["classifier"] = c.export
    save
  end
  
  def classifier
    c = Bishop::Bayes.new { |probs,ignore| Bishop::robinson( probs, ignore ) }
    c.load_data(self["classifier"]) if self["classifier"]
    c
  end
  
  def prep(user, text)
    "twitteruser#{user} #{text}"
  end
  
  def score(user, text)
    c = classifier.guess prep(user, text)
    c = c.inject({}){|memo, (k,v)| memo[k]=v;memo}
    c["good"].to_f - c["bad"].to_f
  end
end

class Vote < ActiveRecord::Base
  belongs_to :user
end

class FilterCallback < ZippyXMLCallback
  def transform(doc)
    doc.find("//status").each do |status|
      user = status.find_first("user/screen_name").content
      text = status.find_first("text").content
      if @user.score(user, text) < 0
        status.remove!
      end
    end
  end
end

class FavoriteCallback < ZippyXMLCallback
  def initialize(request, keyword)
    super(request)
    @value = keyword == "create" ? 1 : -1
  end
  
  def transform(doc)
    doc.find("//status").each do |status|
      guid = status.find_first("id").content
      speaker = status.find_first("./user/screen_name").content
      content = status.find_first("./text").content
      vote = Vote.find_or_initialize_by_tweet_guid_and_user_id_and_speaker_handle(guid, @user.id, speaker)
      vote.content = content
      vote.value = @value
      vote.save
    end    
    @user.update_classifier
  end
end


use SimpleProxy do |request|
  
    puts request.env.inspect
  case request.path 
  when %r[/statuses/home_timeline.xml]
    
    ["twitter.com", FilterCallback.new(request)]
  when %r[/favorites/(\w+)/(\d+).xml]
    ["twitter.com", FavoriteCallback.new(request, $1)]
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
    redirect "/admin" and return
  end
  if client = logged_in_client
    @timeline = client.home_timeline
    @favs = client.favorites
    session[:handle] = client.verify_credentials["screen_name"]
    @user = User.find_or_create_by_handle(session[:handle])
    erb :admin
  else
    redirect token.authorize_url
  end
end