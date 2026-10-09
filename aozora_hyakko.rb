#!ruby
#encoding: utf-8
#aozora_hyakko.rb

require "fileutils"

FileUtils.mkdir_p("hyakko")

src="aozora_all.txt"
prefix="a"
s=File.read(src,encoding:"UTF-8")
works=s.split(/(?=^💎)/)
# 先頭の青空文庫作成情報を最初の作品へ付ける
if !works[0].start_with?("💎")
  works[1]=works[0]+works[1]
  works.shift
end
total=s.size
puts "全体文字数：#{total}"
puts "作品数：#{works.size}"
no=1
rest=works.dup
while rest.size>0
  files_left=100-no+1
  # 最後のファイルなら残り全部
  if files_left==1
    buf=rest.join
    rest.clear
  else
    rest_size=rest.sum(&:size)
    target=rest_size.to_f/files_left
    buf=""
    size=0
    loop do
      work=rest.first
      break unless work
      # これ以上作品を取ると、残りファイルに作品を割り当てられない
      break if rest.size<=files_left-1
      before=(size-target).abs
      after=(size+work.size-target).abs
      break if size>0 && after>before
      buf << rest.shift
      size+=work.size
    end
  end
  filename="#{prefix}#{format("%03d",no)}.txt"
  File.write("hyakko/"+filename,buf,encoding:"UTF-8")
  puts "#{filename}  #{buf.size}文字"
  no+=1
end

__END__
src="aozora_all.txt"
prefix="a"
s=File.read(src,encoding:"UTF-8")
total=s.size
target=total/100.0
works=s.split(/(?=^💎)/)
puts "全体文字数：#{total}"
puts "目標文字数：#{target.to_i}"
puts "作品数：#{works.size}"
no=1
buf=""
size=0
works.each_with_index{|work,i|
  if !buf.empty? && (size+work.size-target).abs > (size-target).abs
    File.write("hyakko/#{prefix}#{format("%03d",no)}.txt",buf,encoding:"UTF-8")
    puts "#{prefix}#{format("%03d",no)}.txt  #{size}文字"
    no+=1
    buf=""
    size=0
  end
  buf<<work
  size+=work.size
}
unless buf.empty?
  File.write("hyakko/#{prefix}#{format("%03d",no)}.txt",buf,encoding:"UTF-8")
  puts "#{prefix}#{format("%03d",no)}.txt  #{size}文字"
end
