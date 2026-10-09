#!ruby
#encoding:utf-8
#gaiji_torikomi.rb

$stdout=open("tmp_gai.txt","w")
$stderr=open("tmp_err.txt","w")

require "fileutils"

dir="c:/users/user/appdata/roaming/hidemaruo/hidemaru/macro/yomipro/replace/"
#replace14.txtをハッシュにする
rep14=File.read(dir+"replace14.txt",encoding:"BOM|UTF-8")
  .lines
  .map{|line| line.chomp.split(",",2)}
  .to_h{|code,char| [code.split("-").map(&:to_i),char]}
text=""
filename=""
FileUtils.mkdir_p("text")
File.foreach("aozora_all.txt"){|line|
  if line.start_with?("💎") #ファイルの区切り
    File.write("text/#{filename}","\uFEFF#{text}") unless filename.empty?
    filename=line.chomp.delete_prefix("💎")
    text=""
    next
  end
  #外字を変換
  line.scan(/※［＃[^］]+］/).uniq.each{|gaiji|
    code=gaiji[/[0-9]+-[0-9]+(?:-[0-9]+)?/]
    next unless code
    code=code.split("-").map(&:to_i)
    if replacement=rep14[code]
      line.gsub!(gaiji,replacement)
    end
  }
  text << line
}
File.write("text/#{filename}","\uFEFF#{text}") unless filename.empty?
