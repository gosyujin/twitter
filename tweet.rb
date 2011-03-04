# -*- encoding: UTF-8 -*-
require 'rubygems'
require 'pit'
require 'openssl'
require 'uri'
require 'net/http'
require 'nkf'
require 'time'

# 署名
def sigunature(method, 
		consumer_secret, 
		oauth_token_secret, 
		url, 
		oauth_header=nil)
	# sigunature_keyの作成
	# リクエストトークン時は"CONSUMER_SECRET&"(アンドが入っている)
	# アクセストークン時は"CONSUMER_SECRET&OAUTH_TOKEN_SECRET"として使用
	sigunature_key = consumer_secret + "&"
	if !oauth_token_secret.nil? then
		sigunature_key += oauth_token_secret
	end

	param = sort_and_concat(oauth_header)

	# メソッド + URL + パラメータ
	value = method + "&" + escape(url) + "&" + escape(param)
	# hmac_sha1
	sha1 = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, sigunature_key, value)
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

# -------------------------------------------------------------

# 引数が0個の場合終了する
if ARGV.length == 0 then
	print "使い方: tweet.rb TWEET PROXY\n"
	exit
end

# ツイート用URL
update_url = "http://twitter.com/statuses/update.json"
url = update_url

text = escape(ARGV[0])
# コマンドプロンプトはutf8変換
# text = escape(NKF.nkf('-w', ARGV[0]))
proxy = ARGV[1]

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

# oauthパラメータたち(決め打ちのもの)
oauth_header = {
	# Consumer Key
	"oauth_consumer_key" => consumer_key,
	# 一意な値
	"oauth_nonce" => OpenSSL::Digest::Digest.hexdigest('MD5', "#{Time.now.to_f}#{rand}"), 
	# 署名方式(HMAC-SHA1)
	"oauth_signature_method" => "HMAC-SHA1",
	# リクエスト生成時のタイムスタンプのミリ秒
	"oauth_timestamp" => Time.now.to_i.to_s, 
	# バージョン(1.0)
	"oauth_version" => "1.0",

	# アクセストークン
	"oauth_token" => oauth_token
}

# headerにツイート追加
oauth_header["status"] = text

# 署名生成
oauth_header["oauth_signature"] = sigunature("POST",
					consumer_secret,
					oauth_token_secret,
					url,
					oauth_header)

# headerからツイート削除
oauth_header.delete("status")
# 署名エンコード
oauth_header["oauth_signature"] = escape(oauth_header["oauth_signature"])
param = sort_and_concat(oauth_header)

param = param.gsub('&', ',')

header = {
	"Authorization" => "OAuth " + param
}

# POST
uri = URI.parse(update_url)
proxy_class = Net::HTTP::Proxy(proxy, 8080)
http = proxy_class.new(uri.host)
http.start do |http|
	res = http.post(uri.path, "status=#{text}", header)

	if res.code == "200" then
		print "#{res.code} tweet: #{ARGV[0]}\n"
	else
		print "ERROR: #{res.code}\n #{res.body}\n"
	end
end
