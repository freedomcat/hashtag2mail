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

class HashtagCloudCsvApi
	def initialize(hashtag,yyyy=nil,mm=nil,dd=nil)
		@hashtag = hashtag
		@ymd = nil 
		if(yyyy==nil) then
			day = Date::today
			day = day - 1
			@ymd = day.to_s

		elsif(yyyy!=nil && mm!=nil && dd!=nil) then
			@ymd = yyyy+"-"+mm+"-"+dd
		end

		setSubject

		tmp = "./tmp/"
		url = "http://hashtagcloud.net/output-file/type=csv&name="+@hashtag+"&start_date="+@ymd+"/"+hashtag+"_"+@ymd+".csv.txt"
		@readcsv = tmp+@hashtag+@ymd+".csv"
		open(@readcsv,'wb') do |file|
			file.puts Net::HTTP.get_response(URI.parse(url)).body
		end

		@writetxt = tmp+@hashtag+@ymd+".txt"

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
		tweet = [] 

		CSV.open(@readcsv,'r'){ |row|

			msg = CGI.unescapeHTML(row[TWEET_CELL])

			footer = row[TWITTERID_CELL]+"\t"+row[TIME_CELL]+"\r\n"+"<"+row[STATUS_CELL]+">"+"\r\n"

			msgAddFlg = TRUE 
			rtmsg = msg.gsub(/^RT\s@\w+?:\s/){$1}
			tweet.each do |tmp|
				if(msg==tmp.msg || rtmsg==tmp.msg) then
					tmp.footer.concat(footer)
					msgAddFlg = FALSE 
				end
			end
			if( msgAddFlg ) then
				tmp = Tweets.new( msg, footer)
				tweet.push(tmp)
			end
		}

		open(@writetxt,'w'){ |writer|
			writer.print("=== twitter [#"+@hashtag+"] �Ɋւ���"+@ymd+"�̌�������\r\n")

			tweet.each do |tmp|
				writer.print("\r\n")
				writer.print(tmp.msg.to_s+"\r\n")
				writer.print(tmp.footer.to_s+"\r\n")
			end

			writer.print("\r\n\r\n")

			writer.print("���̃��[����"+"<http://hashtagcloud.net/info/"+@hashtag+">"+"�̃f�[�^�𗘗p�������肵�Ă��܂��B\r\n")
		}
	end

	def setSubject()
		@subject = @ymd+" twitter #"+@hashtag+"�̂܂Ƃߓǂ�"
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


csv=HashtagCloudCsvApi.new(hashtag)

ymd = csv.getHashTagDate
subject = Kconv.tojis( csv.getSubject() )

fp = open( csv.getMailBodyFileName )
body=""
fp.each{|line| body.concat( Kconv.tojis(line) ) }

#SendGMail.new(from,to,subject,body,from,pass)
SendMail.new(from,to,subject,body)
