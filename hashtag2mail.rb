require 'kconv'
require 'csv'
require 'net/http'
require 'uri'
require 'date'
require "rubygems"
require 'tlsmail'
require 'nkf'
require 'net/smtp'
require 'cgi'

#from = "your mail address"
# if from mail use GMail set pass 
# and use SendGMail.new
#pass = "your gmail pass"
#to = "to mail address"
#hashtag = "hashtag no #"

# default yyyy,mm,dd = nil get yestarday data.

year = nil 
month = nil 
date = nil 

# if you get unique day data. you set date.
#year = "2011" 
#month = "05"
#date = "10"

class HashtagCloudCsvApi

	def initialize(hashtag,yyyy=nil,mm=nil,dd=nil)

		@hashtag = hashtag

		@ymd = setYmd(yyyy,mm,dd) 

		setSubject

		@readcsv = getHashtagCloudData

		@writetxt = "./tmp/"+@hashtag+@ymd+".txt"

		convertMail

	end

	def getMailBodyFileName
		return @writetxt
	end

	def getHashTagDate
		return @ymd
	end

	def getSubject
		return @subject
	end

	private

	TWITTERID_CELL = 0
	TWEET_CELL = 1
	STATUS_CELL = 2
	TIME_CELL = 3
	ICON_CELL =4

	Tweets = Struct.new(:msg,:footer)

	def convertMail
		tmptweets = [] 
		tweets = []
		retweets = []

		CSV.open(@readcsv,'r'){ |row|

			msg = CGI.unescapeHTML(row[TWEET_CELL])

			footer = row[TWITTERID_CELL]+"\t"+row[TIME_CELL]+"\r\n"+"<"+row[STATUS_CELL]+">"+"\r\n"

			msgAddFlg = TRUE 
			rtmsg = msg.gsub(/^RT\s@\w+?:\s/){$1}
			tmptweets.each do |tweet|
				if(msg==tweet.msg || rtmsg==tweet.msg) then
					tweet.footer.concat(footer)
					msgAddFlg = FALSE 
				end
			end
			if( msgAddFlg ) then
				tweet = Tweets.new( msg, footer)
				tmptweets.push(tweet)
			end
		}

		tmptweets.each do |tweet|
			if( /^RT/ =~ tweet.msg )then
				retweets.push(tweet)
			else
				tweets.push(tweet)
			end
		end

		open(@writetxt,'w'){ |writer|
			writer.print(Kconv.tojis("=== twitter [#"+@hashtag+"] に関する"+@ymd+"の検索結果\r\n"))

			writer.print("\r\n")

			tweets.each do |tweet|
				writer.print("\r\n")
				writer.print(Kconv.tojis(tweet.msg+"\r\n"))
				writer.print(Kconv.tojis(tweet.footer+"\r\n"))
			end

			writer.print("\r\n\r\n")

			retweets.each do |tweet|
				writer.print(Kconv.tojis(tweet.msg+"\r\n"))
				writer.print(Kconv.tojis(tweet.footer+"\r\n"))
			end

			writer.print("\r\n\r\n")

			writer.print(Kconv.tojis("このメールは"+"<http://hashtagcloud.net/info/"+@hashtag+">"+"のデータを利用しお送りしています。\r\n"))
		}
	end

	def getHashtagCloudData

		readcsv = "./tmp/"+@hashtag+@ymd+".csv"

		if( checkToday || !File.exist?(readcsv) )then

			url = "http://hashtagcloud.net/output-file/type=csv&name="+@hashtag+"&start_date="+@ymd+"/"+@hashtag+"_"+@ymd+".csv.txt"

			open(readcsv,'wb') do |file|
				file.puts Net::HTTP.get_response(URI.parse(url)).body
			end
		end

		return readcsv
	end

	def checkToday
		day = Date::today.to_s
		if(@ymd==day)then
			return TRUE  
		else
			return FALSE 
		end
	end

	def setYmd(yyyy=nil,mm=nil,dd=nil)
		ymd = nil
		if(yyyy==nil) then
			day = Date::today
			day = day - 1
			ymd = day.to_s
		elsif(yyyy!=nil && mm!=nil && dd!=nil) then
			ymd = yyyy+"-"+mm+"-"+dd
		end
		return ymd
	end

	def setSubject()
		@subject = @ymd+" twitter #"+@hashtag+"のまとめ読み"
	end
end

class SendGMail
	def initialize(from, to, subject, body, user, pass, host = "smtp.gmail.com", port = 587)
	  body = <<EOT
From: #{from}
To: #{to.to_a.join(",\n ")}
Subject: #{NKF.nkf("-WMm0", subject)}
Date: #{Time::now.strftime("%a, %d %b %Y %X %z")}
Mime-Version: 1.0
Content-Type: text/plain; charset=ISO-2022-JP
Content-Transfer-Encoding: 7bit

#{NKF.nkf("-Wjm0", body)}
EOT

  	Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
  	Net::SMTP.start(host, port, "localhost.localdomain", user, pass, "plain") do |smtp|
   	 smtp.send_mail body, from, to
 	 end
	end
end

class SendMail
	def initialize(from, to, subject, body, host = "localhost", port = 25)
	  body = <<EOT
From: #{from}
To: #{to.to_a.join(",\n ")}
Subject: #{NKF.nkf("-WMm0", subject)}
Date: #{Time::now.strftime("%a, %d %b %Y %X %z")}
Mime-Version: 1.0
Content-Type: text/plain; charset=ISO-2022-JP
Content-Transfer-Encoding: 7bit

#{NKF.nkf("-Wjm0", body)}
EOT
	
	  Net::SMTP.start(host, port) do |smtp|
	    smtp.send_mail body, from, to
	  end
	end
end

#csv=HashtagCloudCsvApi.new(hashtag)
csv=HashtagCloudCsvApi.new(hashtag,year,month,date)

ymd = csv.getHashTagDate
subject = Kconv.tojis( csv.getSubject() )

fp = open( csv.getMailBodyFileName )
body=""
fp.each{|line| body.concat( Kconv.tojis(line) ) }

#SendGMail.new(from,to,subject,body,from,pass)
SendMail.new(from,to,subject,body)
