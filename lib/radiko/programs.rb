# ** coding:utf-8
$KCODE='u'
require 'pp'
require 'rubygems'
require 'nokogiri'
require 'date'
class RadikoPrograms
	attr_accessor :doc,:height_1hour
	def initialize(xml)
		@doc = Nokogiri::XML.parse xml
		@height_1hour = 60 # 一時間あたりのボックス高さ
	end
	def channels
		a =doc.search("stations/station").map{|e| [e.attr('id'),e.search("name").text] }
		h = Hash[*a.flatten]
	end
	def channel_name(channel_id)
		self.channels[channel_id]
	end
	def programs(channel_id)
		a = doc.search("stations/station[@id='#{channel_id}']")
		return unless a.size  >= 1
		return a.first.search('progs/prog')
	end
	def program_2_html(prog_element)
		prg  = RadikoProgram.new(prog_element)
		height_percentage = ((prg.duration.to_f/3600.to_f)*10000).to_i/100.to_f
		html = %$
				<!---番組 -->
				<div class="program" style="height:#{height_percentage}%" dur="#{prg.duration}" start_at="#{prg.start_full_datetime}" >
			       <div class="start_time">#{prg.start_time} <div class="sub_title">#{prg.sub_title}</div></div>
			       <div class="title">#{prg.title} <div class="sub_title">#{prg.sub_title}</div></div>
			       <div class="performer">#{prg.performer}</div>
			       <div class="desc">#{prg.desc}</div>
			       <div class="info">#{prg.info}</div>
				</div>

		$
		return html
	end
	def channel_programs_to_html(channel_id)
		progs = self.programs(channel_id)
	    %|
			<div class="channel" id="#{channel_id}" >
			 <div class="channel_name" >#{self.channel_name(channel_id)}</div>
			 <div class="program_list" >
			   #{progs.map{|prg| self.program_2_html(prg)}.join}
			 </div>
			</div>
		|
	end
	def programs_to_html
		self.channels.keys.sort.map{|e| self.channel_programs_to_html(e) } 
	end


end

class RadikoProgram
	def initialize(node)
		@node = node
	end
	def title
		@node.search("title").text
	end
	def duration
		@node.attr('dur')
	end
	def start_full_datetime
		DateTime.parse(@node.attr('ft'))
	end
	def end_full_datetime
		DateTime.parse(@node.attr('to'))
	end
	def start_time
		self.start_full_datetime.strftime("%H:%M")
	end
	def end_time
		self.end_full_datetime.strftime("%H:%M")
	end
	def performer
		@node.search("pfm").text
	end
	alias personality  performer  #出演者
	def desc
		@node.search("desc").text #概要：短文
	end
	def info
		@node.search("info").text #詳細説明：本文 desc / info のどちらが多く使われる。まれに両方もある。
	end
	def sub_title
		@node.search("sub_title").text #サブタイトル：たまに使われる
	end
	def web_site
		@node.search("url").text #番組ページ
	end

end

if $0 == __FILE__ then
r = RadikoPrograms.new(open("/home/takuya/radiko/log/programs/2012-10-14.xml").read)

puts r.programs_to_html

end
