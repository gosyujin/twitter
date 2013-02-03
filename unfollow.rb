# encoding: utf-8
require 'rubygems'
require 'pit'
require 'ruby-growl'
require 'net/http'
require 'oauth'
require 'cgi'
require 'json'
# friends: フォローしている, follower: フォローされている

def all_ids(end_point)
  sleep(1)
  uri = URI.parse("http://api.twitter.com/1/#{end_point}/ids.json")
  proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
  http = proxy_class.new(uri.host)
  http.start do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    request.oauth!(http, @consumer, @access_token) # OAuthで認証
    http.request(request) do |response|
      if response.code == "200" then
        return JSON.parse(response.body)["ids"]
      else
        puts response.code
        puts response.body
        exit 1
      end
    end
  end
end

def user(user_id)
  sleep(1)
  uri = URI.parse("http://api.twitter.com/1/users/show.json")
  proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
  http = proxy_class.new(uri.host)
  http.start do |http|
    request = Net::HTTP::Get.new(uri.request_uri + "?user_id=#{user_id}")
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

def destroy_follow(screen_name)
  sleep(1)
  uri = URI.parse("http://api.twitter.com/1/friendships/destroy.json")
  proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
  http = proxy_class.new(uri.host)
  http.start do |http|
    request = Net::HTTP::Post.new(uri.request_uri + "?screen_name=#{screen_name}")
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

def unfollow_oneway_follower(friends, followers)
  lovelove = false

  friends.each do |friend|
    #puts user(friend)["screen_name"]
    followers.each do |follower|
      #puts user(follower)["screen_name"]
      if friend == follower then
        lovelove = true
        break
      else
        lovelove = false
      end
    end

    if lovelove then
      #screen_name = user(friend)["screen_name"]
      #puts "followed by #{"screen_name"}"
    else
      screen_name = user(friend)["screen_name"]
      destroy_follow(screen_name)
      sleep(4)
      puts "NOT followed by #{screen_name} and KILL"
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

unfollow_oneway_follower(all_ids("friends"), all_ids("followers"))
