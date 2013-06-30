# encoding: utf-8
require 'rubygems'
require 'pit'
require 'net/http'
require 'oauth'
require 'json'
# friends: フォローしている, follower: フォローされている


def my_list
  sleep(1)
  uri = URI.parse("http://api.twitter.com/1.1/followers/list.json")
  proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
  http = proxy_class.new(uri.host)
  http.start do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    request.oauth!(http, @consumer, @access_token) # OAuthで認証
    http.request(request) do |response|
      if response.code == "200" then
        return JSON.parse(response.body)
      else
        puts response.code
        puts response.body
        exit 1
      end
    end
  end
end

def follow(list)
  list["users"].each do |l|
    sleep(1)
    # 自分をフォローしているユーザと自分がフォローしているかを表示
    # puts "#{l["following"]} #{l["screen_name"]}"
    # 自分がフォローしていないユーザの場合
    unless l["following"] then
      uri = URI.parse("http://api.twitter.com/1.1/friendships/create.json")
      proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
      http = proxy_class.new(uri.host)
      http.start do |http|
        request = Net::HTTP::Post.new(uri.request_uri + "?screen_name=#{l["screen_name"]}")
        request.oauth!(http, @consumer, @access_token) # OAuthで認証
        http.request(request) do |response|
          if response.code == "200" then
            puts "#{l["screen_name"]} is follow"
            return JSON.parse(response.body)
          else
            puts "#{response.code} #{response.body}"
          end
        end
      end
    else
      puts "#{l["screen_name"]} is already followed"
    end
  end
end

core = Pit.get("twitter", :require => {
  "consumer_key" => "your consumer_key",
  "consumer_secret" => "your consumer_secret",
  "oauth_token" => "your oauth_token",
  "oauth_token_secret" => "your oauth_token_secret"
})

@consumer = OAuth::Consumer.new(
  core["consumer_key"],
  core["consumer_secret"],
  :site => 'http://twitter.com')

@access_token = OAuth::AccessToken.new(
  @consumer,
  core["oauth_token"],
  core["oauth_token_secret"])

follow(my_list)
