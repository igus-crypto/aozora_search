#!ruby
#encoding: utf-8
#read_time.rb

$stdout=open("read_time.txt","w")
$stderr=open("tmp_err.txt","w")

#605文字/min
print "\uFEFF"
n,f,hash=605,"",{}
open("aozora_all.txt").each_line{|line|
  if %r|^💎(.*)|=~line
    hash[f]=n/605 unless f==""
    f=line.chomp.sub("💎","")
    n=605
  else
    n+=line.size
  end
}

#最後の作品を登録
hash[f]=n/605 unless f==""

hash.each{|k,v|
  h=sprintf("%02d",v/60)
  m=sprintf("%02d",v%60)
  puts "#{k},#{h}h#{m}min"}
