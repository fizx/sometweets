require 'rubygems'

require 'activerecord'
dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig['production']

require 'sinatra'
require 'rack/streaming_proxy'

SERVE_CONTENT = nil

use Rack::StreamingProxy do |request|
  case request.path 
  when %r[^/(search|trends)]
  when %r[^/(admin|$)]
    SERVE_CONTENT
  else
    "http://api.twitter.com/#{request.path}"
  end
end

get "/" do
  "This will eventually be an admin page"
end