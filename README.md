radiko-lock-on
==============

Radikoの録音をLinuxから行うWEBアプリ(HTMLベース)Radikoの予約録音です。

#動作に不可欠なもの
rtmpdump 2.4
at コマンド
ruby 1.8.7
rubygems
sinatra

#インストール

apt-get install rtmpdump
apt-get install ruby
apt-get install swftools
sudo su -
gem install sinatra
gem install activesupport
     

#
#必要な設定
# ApacheのCGIで動かす
sudo a2enmod rewrite
sudo a2enmod cgi
ln -s 2www /var/www/radiko

<directory /var/www/radiko>
	Allowoveride All #追加
</directory>


#パーミッション設定
sudo chmod -R a+w media
sudo chmod -R a+w log 
sudo chmod -R a+x bin/*


/radiko/
.
├── bin
│   ├── radiko_programs
│   ├── radiru.rb
│   └── rec_radiko
├── etc
├── lib
│   ├── radiko
│   │   └── programs.rb
│   └── radiko.rb
├── log
│   ├── programs
│   │   ├── 20:wq12-10-14.xml
│   │   └── 2012-10-15.xml
│   └── reserves
│       ├── 2012-10-14.json
│       └── 2012-10-15.json
├── media
├── templates
│   ├── index.erb
│   └── main.erb
└── www
    ├── index.cgi
    ├── static
    │   └── jquery.js
    └── tmp




