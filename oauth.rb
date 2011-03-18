require 'rubygems'
require 'pit'
require 'openssl'
require 'uri'
require 'net/http'

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

# リクエストトークン取得用のURL
request_token_url = "http://twitter.com/oauth/request_token"
# PINコード取得用URL
authorize_url = "http://twitter.com/oauth/authorize"
# アクセストークン取得用のURL
access_token_url = "http://twitter.com/oauth/access_token"

# Twitterで登録したらもらえる
consumer = Pit.get("twitter", :require => {
	"consumer_key" => "your consumer_key",
	"consumer_secret" => "your consumer_secret"
})
consumer_key = consumer["consumer_key"]
consumer_secret = consumer["consumer_secret"]
# pitを使わずにべた書き用
# consumer_key = CONSUMER_KEY
# consumer_secret = CONSUMER_SECRET

# Twitterからもらえるアクセストークン(最初は使わない)
oauth_token = ""
oauth_token_secret = ""

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
}

# signature作成
oauth_header["oauth_signature"] = signature("GET", 
					consumer_secret, 
					nil, 
					request_token_url, 
					oauth_header)

# GETする
uri = URI.parse(request_token_url)
proxy_class = Net::HTTP::Proxy(ARGV[0], 8080)
http = proxy_class.new(uri.host)
http.start do |http|
	# oauth_headerのパラメータをソートして連結
	param = sort_and_concat(oauth_header)
	res = http.get(uri.path + "?#{param}")

	if res.code == "200" then
		# 返ってきた値を分割
		params = res.body.split("&")
		params.each do |param|
			# さらに=で分割し前部分をkey、後方部分をvalueに格納
			key,value = param.split("=")

			# リクエストトークンを格納
			if ("oauth_token" == key) then
				oauth_token = value
			elsif ("oauth_token_secret" == key) then
				oauth_token_secret = value
			end
		end

		# プロンプトにPINコード取得用URL表示
		print "#{authorize_url}?oauth_token=#{oauth_token}\n"
		print "Input PIN Code. Input...\n"

		# PINコード入力待ち
		oauth_verifier = STDIN.gets
		# 改行コード(\n)取り除き
		oauth_verifier = oauth_verifier.slice(0, oauth_verifier.length-1)

		# ヘッダにアクセストークンとPINコード追加
		oauth_header["oauth_token"] = oauth_token
		oauth_header["oauth_verifier"] = oauth_verifier
		
		# いったんoauth_signature削除
		oauth_header.delete("oauth_signature")

		# 再びsignature作成
		oauth_header["oauth_signature"] = signature("GET", 
							consumer_secret, 
							oauth_token_secret, 
							access_token_url, 
							oauth_header)

		# oauth_headerのパラメータをソートして連結
		param = sort_and_concat(oauth_header)

		# GETする
		uri = URI.parse(access_token_url)
		proxy_class = Net::HTTP::Proxy(ARGV[0], 8080)
		http = proxy_class.new(uri.host)
		http.start do |http|
			res = http.get(uri.path + "?#{param}")
			if res.code =="200" then
				print "#{res.code}\n"
				print "#{res.body}\n"
			else
				print "ERROR: #{res.code}\n"
			end
		end
	else
		print "ERROR: #{res.code}\n"
	end
end
