#! -*- encoding: utf-8 -*-
require "twitter_cui/version"
require "twitter_cui/api_url"

require 'pit'
require 'oauth'
require 'net/http'
require 'thor'
require 'json'

module TwitterCui
  class CLI < Thor
    include Api_Url

    Config = YAML.load_file("_config.yml")
    require 'pp' ; pp Config

    Pit_Id = Config["pit_id"]
    Ca_Path = Config["cer_file_path"]
    Ng_Array = Config["ng_word"]

    # consumer_key, secret, access_token, secret
    Core = Pit.get(Pit_Id)
    Consumer = OAuth::Consumer.new(
      Core["consumer_key"],
      Core["consumer_secret"],
      :site => "https://twitter.com"
    )
    Access_Token = OAuth::AccessToken.new(
      Consumer,
      Core["oauth_token"],
      Core["oauth_token_secret"]
    )

    class_option :help, :type => :boolean, :aliases => '-h', :desc => "twitter_cui help"

    desc "[g|get] [-m|-s]", "get recent user timeline"
    option :own,     :type => :boolean, :aliases => '-o', :desc => "get own tweet"
    option :mention, :type => :boolean, :aliases => '-m', :desc => "get resent mentions"
    option :stream,  :type => :boolean, :aliases => '-s', :desc => "start connect usestream"
    def get
      if options[:mention] then
        d = attack(:GET, Mentions_Timeline)
        output(d)
      elsif options[:stream] then
        attack(:GET, User_Stream)
      elsif options[:own] then
        d = attack(:GET, User_Timeline)
        output(d)
      else
        d = attack(:GET, Home_Timeline)
        output(d)
      end
    end

    desc "[t|tweet]", "next, input tweet and enter"
    def tweet(text)
      d = attack(:POST, "#{Statuses_Update}?status=#{URI.escape(text)}") unless ng?(text.encode("UTF-8"))
    end

    desc "[r|reply]", "next, select in_reply_to tweet and input tweet and enter"
    def reply
      puts "reply"
    end

    desc "[u|user]", "next, select user"
    def user
      puts "user"
    end

private
    def output(data)
      json = JSON.load(data)
      json.reverse.each do |j|
        screen_name = j["user"]["screen_name"]
        name = j["user"]["name"]
        text = j["text"]
        created_at = j["created_at"]
        in_reply_to = j["in_reply_to_screen_name"]

        out = "** #{screen_name} ( #{name} )"
        out << " reply to #{in_reply_to}" unless in_reply_to.nil?
        out << " | #{created_at}"
        out << "\n"
        out << "#{text}"
        out << "\n"
        out << "-------------------------------------------------"
        puts out
      end
    end

    def ng?(text)
      Ng_Array.each do |ng|
        if text.match(/#{ng}/) then
          puts "Warn: NG WORD: '#{ng}'"
          return true
        end
      end
      puts "OK"
      return false
    end

    def ca_file
      ca_path = Ca_Path
      ca_file = File.expand_path(ca_path)
      if FileTest.exist?(ca_file) then
        ca_file
      else
        puts "ca_file not found"
        exit 1
      end
    end

    def attack(method, end_point, header=nil, body=nil)
      uri = URI.parse(end_point)
      if ENV['proxy'] == "" and ENV['proxy_port'] == "" then
        #puts "not proxy"
        http = Net::HTTP.new(uri.host, uri.port)
      else
        #puts "use proxy"
        http = Net::HTTP.Proxy(ENV['proxy'], ENV['proxy_port']).new(uri.host, uri.port)
      end

      if uri.scheme == "https" then
        http.use_ssl = true
        http.ca_file = ca_file
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_depth = 5
      end

      http.start do |http|
        case method
        when :GET
          req = Net::HTTP::Get.new(uri.request_uri)
          req.oauth!(http, Consumer, Access_Token)
          http.request(req) do |res|
            return res.body
          end
        when :POST
          req = Net::HTTP::Post.new(uri.request_uri, header)
          req.oauth!(http, Consumer, Access_Token)
          http.request(req) do |res|
            return res.body
          end
#          res.read_body do |chunk|
#            buf = chunk
#            begin
#              status = JSON.parse(buf.strip)
#              if status['text'] then
#                puts "#{status['user']['screen_name']}: \n#{status['text']}\n--------"
#              end
#            rescue EOFError => ex
#              puts "EOF E"
#            rescue JSON::ParserError => ex
#              puts "JSON P"
#            end
#          end
        else
          puts "else"
        end
      end
    end
  end
end
