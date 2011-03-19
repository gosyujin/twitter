#!/bin/ruby

require 'rubygems'
require 'pit'
require 'openssl'
require 'uri'
require 'net/http'
# http://rubyforge.org/snippet/detail.php?type=snippet&id=148
require 'simplejsonparser'
require 'nkf'
require 'time'
require 'pp'

# signature作成
def signature(method, consumer_secret, oauth_token_secret, url, oauth_header)
	# signature_keyの作成
	# リクエストトークン時は"CONSUMER_SECRET&"(アンドが入っている)
	# アクセストークン時は"CONSUMER_SECRET&OAUTH_TOKEN_SECRET"として使用
	signature_key = consumer_secret + "&"
	if !oauth_token_secret.nil? then
		signature_key += oauth_token_secret
	end

	# oauth_headerのパラメータをソートして連結
	param = sort_and_concat(oauth_header)

	# httpメソッドとURLとパラメータを&で連結する
	value = method + "&" + escape(url) + "&" + escape(param)
	# hmac_sha1
	sha1 = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, signature_key, value)
	# base64
	base64 = [sha1].pack('m').gsub(/\n/, '')
	return base64
end

# 文字列のエスケープ(: / = %をエスケープする。. _ -はそのまま)
def escape(value)
	URI.escape(value, Regexp.new("[^a-zA-Z0-9._-]"))
end

# oauth_headerの情報をアルファベット順に並べ替え & で結合
def sort_and_concat(oauth_header)
	oauth_header_array = oauth_header.sort
	param = ""
	oauth_header_array.each do |params|
		for i in 1..params.length
			param += params[i-1]
			if i % params.length == 0
				param += "&"
			else
				param += "="
			end
		end
	end
	param = param.slice(0, param.length-1)
end

# 自分のフォロワーのステータス確認url
url = "http://api.twitter.com/1/statuses/followers.json"

twitter = Pit.get("twitter", :require => {
	# Twitterで登録したらもらえる
	"consumer_key" => "your consumer_key", 
	"consumer_secret" => "your consumer_secret", 
	# Twitterからもらえるアクセストークン
	"oauth_token" => "your oauth_token", 
	"oauth_token_secret" => "your oauth_token_secret"
})
consumer_key = twitter["consumer_key"]
consumer_secret = twitter["consumer_secret"]
oauth_token = twitter["oauth_token"]
oauth_token_secret = twitter["oauth_token_secret"]
# pitを使わずにべた書き用
# consumer_key = CONSUMER_KEY
# consumer_secret = CONSUMER_SECRET
# oauth_token = OAUTH_TOKEN
# oauth_token_secret = OAUTH_TOKEN_SECRET

# oauthパラメータたち
oauth_header = {
	# Consumer Key
	"oauth_consumer_key" => consumer_key,
	# 一意な値(今回は適当に実装)
	"oauth_nonce" => "AAAAAAAA",
	# 署名方式(HMAC-SHA1)
	"oauth_signature_method" => "HMAC-SHA1",
	# リクエスト生成時のタイムスタンプ(ミリ秒)
	"oauth_timestamp" => Time.now.to_i.to_s,
	# バージョン(1.0)
	"oauth_version" => "1.0",

	# アクセストークン
	"oauth_token" => oauth_token 
}

# signature作成
oauth_header["oauth_signature"] = signature("GET", 
					consumer_secret, 
					oauth_token_secret, 
					url, 
					oauth_header)

# GETする
uri = URI.parse(url)
proxy_class = Net::HTTP::Proxy(ARGV[0], 8080)
http = proxy_class.new(uri.host)
http.start do |http|
	# oauth_headerのパラメータをソートして連結
	param = sort_and_concat(oauth_header)
	res = http.get(uri.path + "?#{param}")
	if res.code == "200" then
		json = res.body
		# jsonparseでparseしてもらう
		jsonparse = JsonParser.new.parse(json)
		for i in 0..jsonparse.length - 1
			# 自分をフォローしているユーザと自分がフォローしているかを表示
			# print "#{jsonparse[i]["following"]} #{jsonparse[i]["screen_name"]}\n"
			# 自分がフォローしていないユーザの場合
			if !jsonparse[i]["following"] then
				# 指定ユーザをフォローするUrl
				url = "http://api.twitter.com/1/friendships/create/#{jsonparse[i]["id"]}.json"
				# signatureつくり直し
				oauth_header.delete("oauth_signature")
				# signature作成
				oauth_header["oauth_signature"] = signature("POST",
									consumer_secret,
									oauth_token_secret,
									url,
									oauth_header)
				oauth_header["oauth_signature"] = escape(oauth_header["oauth_signature"])
				# POST
				uri = URI.parse(url)
				proxy_class = Net::HTTP::Proxy(ENV["PROXY"], 8080)
				http = proxy_class.new(uri.host)
				http.start do |http|
					param = sort_and_concat(oauth_header)
					param = param.gsub('&', ',')
					header = {
						"Authorization" => "OAuth " + param
					}
					res = http.post(uri.path, "", header)
					
					if res.code == "200" then
						print "#{jsonparse[i]["screen_name"]} follow now!\n"
						sleep(1)
					else
						print "#{res.code} #{jsonparse[i]["id"]}:#{jsonparse[i]["screen_name"]}\n"
					end
				end
			end
		end
	else
		print "#{res.code}\n"
	end
end
