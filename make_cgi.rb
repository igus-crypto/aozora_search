#!ruby
#encoding:utf-8
#make_cgi.rb

require "fileutils"
require "base64"

FileUtils.mkdir_p("cgi")

# ao_grep.csv からハッシュを作る
hs = {}
File.foreach("ao_grep.csv", encoding: "UTF-8") do |line|
  a = line.chomp.split(%r|,(?! )|)
  hs[a[0]] = [a[1], a[2], a[3], a[4]] unless hs[a[0]]
end
# cgi_org.rb を📿で分割
ar = File.read(
  "cgi_org.rb",
  encoding: "UTF-8"
).split("📿", 2)
unless ar.length == 2
  abort "cgi_org.rb に📿がありません"
end
## a001.txt ～ a100.txt を一つずつ処理
(1..100).each do |n|
  file = format("a%03d.txt", n)
  cgi  = format("ag_%03d.cgi", n)
  puts "#{file} を読み込み中..."
  text = File.read("hyakko/"+file, encoding: "UTF-8")
  puts "  Marshal化中..."
  data = Base64.encode64(
    Marshal.dump([hs, text])
  )
  puts "  #{cgi} を作成中..."
  File.write(
    "cgi/"+cgi,
    ar[0] +
    data +
    ar[1],
    encoding: "UTF-8"
  )
  puts "  #{cgi}: #{File.size("cgi/"+cgi)} bytes"
  puts "  #{file}: #{text.lines.count} 行"
end
puts "完了しました"
puts "hs: #{hs.length} 件"
