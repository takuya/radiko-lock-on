#!/usr/bin/env ruby
# coding:utf-8
# modified at 2012-10-14 
# modifled by takuya_1st
# contact  http://d.hatena.ne.jp
# 
require 'pp'
require "open-uri"
require "net/http"
require 'openssl'


I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = true
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE #とりあえずこれで
#http://d.hatena.ne.jp/urekat/20070201/1170349097
module Net
		class HTTPRequest
				self.class_eval{
						attr_reader :postdata
						def initialize(path, initheader = nil)
								klass = initheader["postdata"] ? HTTP::Post : HTTP::Get if initheader
								@postdata = initheader.delete("postdata")
								super klass::METHOD,
										klass::REQUEST_HAS_BODY,
										klass::RESPONSE_HAS_BODY,
										path, initheader
						end
				}
		end
		class HTTP
				self.class_eval{
						alias :_request :request
						def request(req, body = nil, &block)
								body = req.postdata if req.respond_to?(:postdata)
								_request(req, body, &block)
						end
				}
		end
end
class Radiko
		attr_accessor :channel,:output,:time_length,:areaid
		def initialize
				@playerurl   = "http://radiko.jp/player/swf/player_2.0.1.00.swf"
				@playerfile  = "/tmp/player.swf"
				@keyfile     = "/tmp/authkey.png"
				@channel     = nil
				@output      = nil
				@areaid      = nil
				@time_length = 1800
		end
		def auth

				self.get_player
				self.get_keydata
				self.auth1_fms
				self.auth2_fms

				
		end
		def auth1_fms
				#
				# access auth1_fms
				#
				@auth1_fms = open("https://radiko.jp/v2/api/auth1_fms", 
								 					{ "pragma"              =>  " no-cache",
														 "X-Radiko-App"         =>  " pc_1",
														 "X-Radiko-App-Version" =>  " 2.0.1",
														 "X-Radiko-User"        =>  " test-stream",
														 "X-Radiko-Device"      =>  " pc",
														 "postdata"             =>  '\r\n'
													}
												).read
				#
				if(@auth1_fms.size < 1) then
						puts "-"*20
						puts "failed auth1 process"
						exit
				end
				#
				# get partial key
				#
				@authtoken  = (/x-radiko-authtoken=([\w-]+)/i).match(@auth1_fms).to_a[1].strip
				@offset     = (/x-radiko-keyoffset=(\d+)/i).match(@auth1_fms).to_a[1].strip
				@length     = (/x-radiko-keylength=(\d+)/i).match(@auth1_fms).to_a[1].strip
				@partialkey = `dd if=#{@keyfile} bs=1 skip=#{@offset} count=#{@length} 2> /dev/null | base64`.strip
			    puts "authtoken: #{@authtoken} \noffset: #{@offset} length: #{@length} \npartialkey: #{@partialkey}"

		end
		def auth2_fms
				#
				# access auth2_fms
				#
				@auth2_fms = open("https://radiko.jp/v2/api/auth2_fms",
														 {
																"pragma"                =>  " no-cache" ,
																"X-Radiko-App"          =>  " pc_1" ,
																"X-Radiko-App-Version"  =>  " 2.0.1" ,
																"X-Radiko-User"         =>  " test-stream" ,
																"X-Radiko-Device"       =>  " pc" ,
																"X-Radiko-Authtoken"    =>  " #{@authtoken}" ,
																"X-Radiko-Partialkey"   =>  " #{@partialkey}" ,
																"postdata"             =>'\r\n' ,
														}
								).read

				if(@auth2_fms.size < 1) then
						puts "-"*20
						puts "failed auth1 process"
				end

				puts  "authentication success"
				@areaid = @auth2_fms.match(/^([^,]+),/i).to_a[1].strip
				puts "areaid: #{@areaid}"


		end
		def get_player
				#
				# get player
				#
				unless File.exists? @playerfile then
						require'open-uri'
						open(@playerfile,"w"){|f|
								f.write open(@playerurl).read
						}
				end
		end
		def get_keydata
				#
				# get keydata (need swftool)
				#
				unless File.exists? @keyfile then
						`swfextract -b 5 #{@playerfile} -o #{@keyfile}`

						unless File.exists? @keyfile then
								putsh "failed get keydata"
								exit 1
						end
				end
		end
		def get_program()
				self.auth unless @areaid
				raise("エリア情報取得エラー") unless @areaid

				url_today    = "http://radiko.jp/v2/api/program/today?area_id=#{areaid}"
				url_tomorrow = "http://radiko.jp/v2/api/program/tomorrow?area_id=#{areaid}"

				today    = (Time.now - 60*60*5).strftime("%Y-%m-%d").to_s
				tomorrow = (Time.now - 60*60*5+60*60*24).strftime("%Y-%m-%d").to_s

				{
					today   => open(url_today).read,
					tomorrow=> open(url_tomorrow).read,
				
				}
		end

		def rec(channel=nil,time_length=nil,output=nil)
				#
				# rtmpdump
				#
				@channel     = channel      if channel   
				@time_length = time_length  if time_length
				@output      = output       if output

				cmd = %!/usr/bin/rtmpdump -v \
				         -r "rtmpe://radiko.smartstream.ne.jp" \
				         --playpath "simul-stream" \
				         --app "#{@channel}/_defInst_" \
				         -W #{@playerurl} \
				         -C S:"" -C S:"" -C S:"" -C S:#{@authtoken} \
				         --live \
				         --stop #{@time_length.to_i} \
				         -o "#{@output}"

				!
				pid =fork{
					`#{cmd}` #todo spawn にしてゾンビプロセス防止したい
					exit!(0)
				}
				t = Process.detach pid
				sleep @time_length.to_i+1
				Process.kill(:KILL, -1*pid) unless t.nil?
				

		end


end

