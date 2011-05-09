require 'net/http'
require 'uri'
require 'simplejsonparser'

url = "http://stream.twitter.com/1/statuses/sample.json" 
uri = URI.parse(url)
proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
http = proxy_class.new(uri.host)
http.start do |http| 
	request = Net::HTTP::Get.new(uri.request_uri)
 	request.basic_auth("USERNAME", "PASSWORD")
 	http.request(request) do |response|
 		response.read_body do |str| 
			jsonparse = JsonParser.new.parse(str) rescue next
			print "■#{jsonparse["user"]["screen_name"]} #{jsonparse["text"]}\n" rescue next
		end
	end 
end 
