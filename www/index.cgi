#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'

require 'date'
require 'json'
require 'digest/md5'
require 'sqlite3'

BASE_PATH = File.dirname Dir.pwd
LIB_DIR   = "#{BASE_PATH}/lib"
LOG_DIR   = "#{BASE_PATH}/log"
BIN_DIR   = "#{BASE_PATH}/bin"
MEDIA_DIR = "#{BASE_PATH}/media"

$:.unshift LIB_DIR

require 'radiko'
require 'radiko/programs'


set :run, false                #HTTPサーバ立ち上げないならfalse
#set :environment, :production


set :public_folder, File.dirname(__FILE__) + '/static'
set :views        , File.dirname(__FILE__) + '/../templates'

def save_radiko_programs
	prg_save_path = "#{LOG_DIR}/programs/"
	radiko = Radiko.new
	radiko.auth
	prgs =  radiko.get_program
	dates = prgs.keys
	dates.each{|day|
		Dir.chdir(prg_save_path){
			open( "#{day}.xml","w" ){|f| 
			f.write prgs[day]
		}

		}

	}
end

#db = SQLite3::Database.new("#{LOG_DIR}/test.db")


def save_reserve(data)

	day = Date.parse(data["start_at"]).strftime
	reserve_path = "#{LOG_DIR}/reserves/#{day}.json"
	list = [] unless File.exists? reserve_path
	list = JSON.load(open(reserve_path).read) if File.exists? reserve_path
	unless list.include? data then
	    list << data
		add_q(params)
	end
	str = JSON.dump list

	open(reserve_path,"w"){|f| f.write str}

end
def add_q(data)
	md5_str = Digest::MD5.hexdigest(JSON.dump([data["title"],data["start_at"]]))
	d = DateTime.parse data["start_at"]
	cmd =<<-"EOS"
	# reserve_id = #{md5_str}
	# title      = #{data['title']}
	# start_at   = #{data['start_at']}
	#{BIN_DIR}/rec_radiko -c '#{data["channel"]}' -o  '#{MEDIA_DIR}/#{data["title"].strip}@#{d.strftime('%Y-%m-%d')}.m4a' -t '#{data["duration"]}'
	# 
	EOS
	IO.popen("at -q r '#{(d).strftime("%H:%M %d.%m.%Y")}'","w"){|io| io.write cmd;}
end
def del_q(data)
	md5_str = Digest::MD5.hexdigest(JSON.dump([data["title"],data["start_at"]]))
	job_num = `atq -q r`.lines.
			map{|e| e.split.first}.
			map{|e| [e, `at -c #{e} `] }.
			select{|e| e[1]=~/#{md5_str}/}.first[0]
	
	`at -d #{job_num} `
	md5_str
end
def cancel_reserve(data)

	day = Date.parse(data["start_at"]).strftime
	reserve_path = "#{LOG_DIR}/reserves/#{day}.json"
	list = [] unless File.exists? reserve_path
	list = JSON.load(open(reserve_path).read) if File.exists? reserve_path
	
	if list.include? data then
		list.delete data  
		del_q(params)
	end
	str = JSON.dump list

	open(reserve_path,"w"){|f| f.write str}

end


get '/' do       
	day = Date.today.strftime
	prg_xml_path = "#{LOG_DIR}/programs/#{day}.xml"
	save_radiko_programs  unless File.exists? prg_xml_path
	r = RadikoPrograms.new(open(prg_xml_path).read)
	html = r.programs_to_html

	erb :index, :layout => :main, :locals=>{:programs_html=>html,:title=>"#{day}のRadiko番組表", :day => day}
end


post '/reserve' do
	params["start_at"]
	params["duration"]
	params["channel"]
	params["title"]
	#もし、すでに開始してたら、予約せず録音を開始する
	#if Time.parse(params["start_at"]) < Time.now 
	#	system %!{BIN_DIR}/rec_radiko -c '#{params["channel"]}' -o  '#{MEDIA_DIR}/#{params["title"].strip}.flv' -t '#{params["duration"]}'!
	#else
	  save_reserve params
	#end
	"予約しました"

end


post '/cancel_reserve' do
	params["start_at"]
	params["duration"]
	params["channel"]
	params["title"]
	cancel_reserve params
	"予約キャンセルしました"

end

get '/reserve/:day.json' do
	day = params[:day]
	list = []
	reserve_path = "#{LOG_DIR}/reserves/#{day}.json"
	list = [] unless File.exists? reserve_path
	list = JSON.load(open(reserve_path).read) if File.exists? reserve_path
	JSON.dump list
end


get "/rec_list" do
	Dir.entries(MEDIA_DIR).reject{|e| e=~/^\./  }.sort.map{|e|  "<a href='./play?name=#{e}'>#{e}</a>"  }.join("<br/>")
end

get "/send" do
	file = "#{MEDIA_DIR}/#{params[:name]}"
	raise unless File.exists? file
	send_file file , :filename=> params[:name]
end
get "/play" do
	"<html><body><audio src='./send?name=#{params[:name]}'controls autoplay ></audio><a href='./send?name=#{params[:name]}'>download</a></body></html>"
end




Rack::Handler::CGI.run Sinatra::Application

