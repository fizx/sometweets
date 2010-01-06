require "net/http"
class SimpleProxy
  def initialize(app, &block)
    @app = app
    @block = block
  end
  
  def call(env)
    rack_req = Rack::Request.new(env)
    host = @block.call(rack_req)
    return @app.call(env) unless host
    
    http_req = if rack_req.get?
      Net::HTTP::Get.new(rack_req.fullpath)
    else
      r = Net::HTTP::Post.new(rack_req.fullpath)
      r.body = rack_req.POST
      r
    end
    
    rack_req.env.each do |key, value|
      if key =~ /^HTTP_(.*)/
        header = $1.split("_").map(&:capitalize).join("-")
        http_req[header] = value
      end
    end
    
    http_res = Net::HTTP.start(host, 80)  do |http|
      http.request(http_req)
    end
    
    headers = {}
    http_res.each_header {|k,v| headers[k] = v}
    
    [http_res.code, headers, http_res.body]
  end
end