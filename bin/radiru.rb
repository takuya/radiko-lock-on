#!/usr/bin/env ruby
# coding:utf-8
# modified at 2012-10-14 
# modifled by takuya_1st
# contact  http://d.hatena.ne.jp
# 

playerurl   = "http://radiko.jp/player/swf/player_2.0.1.00.swf"
playerfile  = "./player.swf"
keyfile     = "./authkey.png"
channel     = nil
output      = nil
time_length = 1800

require "optparse"

opt = OptionParser.new
opt.on("-c channel_name","--channel","チャンネル (第一/第二/fm)=(r1/r2/fm)"){|v| channel=v}
opt.on("-t [1800]","--time","録音時間（指定なしは、1800秒"){|v| time_length=v}
opt.on("-o [チャンネル名.flv]","--output","出力ファイル"){|v| output=v}
opt.parse! ARGV

output  = "#{channel}.flv" if output==nil
unless channel and ["r1","r2","fm"].include? channel
  ARGV = ["--help"]
  opt.parse! ARGV
  exit
end

channel_num = case channel 
when "fm"
	63343
when "r2"
	63342
when "r1"
	63346
end



#
# rtmpdump
#
cmd = %! rtmpdump --rtmp "rtmpe://netradio-#{channel}-flash.nhk.jp" \
         --playpath 'NetRadio_#{channel.upcase}_flash@#{channel_num}' \
         --app "live" \
         -W http://www3.nhk.or.jp/netradio/files/swf/rtmpe.swf \
         --live \
         -o #{output}.m4a \
         -- stop 14400 
!




pid = Kernel.fork{
  system(cmd)
}
$stdout.flush
sleep time_length.to_i

Process.kill(:INT,0)

