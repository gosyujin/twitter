# encoding: utf-8
require 'rubygems'
require 'pit'
require 'ruby-growl'
require 'net/https'
require 'oauth'
require 'cgi'
require 'json'

core = Pit.get("twitter_kk", :require => {
  "consumer_key" => "your consumer_key",
  "consumer_secret" => "your consumer_secret",
  "oauth_token" => "your oauth_token",
  "oauth_token_secret" => "your oauth_token_secret"
})

consumer = OAuth::Consumer.new(
  core["consumer_key"],
  core["consumer_secret"],
  :site => 'http://twitter.com'
)

access_token = OAuth::AccessToken.new(
  consumer,
  core["oauth_token"],
  core["oauth_token_secret"]
)

uri = URI.parse('https://userstream.twitter.com/2/user.json')

https = Net::HTTP::Proxy(ENV["PROXY"], 8080).new(uri.host, 443)
https.use_ssl = true
https.ca_file = './verisign.cer'
https.verify_mode = OpenSSL::SSL::VERIFY_PEER
https.verify_depth = 5

https.start do |https|
  request = Net::HTTP::Get.new(uri.request_uri)
  request.oauth!(https, consumer, access_token) # OAuthで認証
  https.request(request) do |response|
    response.read_body do |chunk|
      buf = chunk
      # growl = Growl.new("localhost", "MyUsSt", ["Message", "Error"])
      begin
        status = JSON.parse(buf.strip)
        if status['text'] then
          # growl.notify "Message", "#{status['user']['screen_name']}", "#{status['text']}" 
          puts "--------"
          puts "■#{status['user']['screen_name']}:"
          puts "#{status['text']}"
          # puts ">> #{status['in_reply_to_status_id']}"
        end
      rescue EOFError => ex
        # growl.notify "Error", "Error", "#{ex}" 
        puts "EOF E"
      rescue JSON::ParserError => ex
        # growl.notify "Error", "Error", "#{ex}" 
        print "-"
      end
    end
  end
end
