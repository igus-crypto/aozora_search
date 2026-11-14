#!ruby
#encoding: utf-8
#make_csv.rb

$stdout=open("ao_search.csv","w")
$stderr=open("tmp_err.txt","w")

require "csv"

print "\uFEFF"
puts "id,title,author,text_type,inputter,proofreader,"+
  "reading_time,card_url,text_url,html_url"

#read_time.txtを先に読み込む
times={}

File.foreach("read_time.txt",encoding:"UTF-8"){|line|
  txt,time=line.chomp.split(",",2)
  zip = txt.sub(".txt",".zip")
  times[zip]=[txt,time]
}

# 原本の行順で出力し、IDの末尾は従来どおりzipごとに採番する。
zip_counts = Hash.new(0)
File.foreach("list_person_all_extended_utf8.csv", encoding: "UTF-8") do |line|
  s = nil
  times.each do |zip, (txt, time)|
    next unless line.include?(zip)

    s ||= CSV.parse_line(line)
    if /^[ァ-ヴー・]+$/=~s[15] + s[16]
      name=s[16] +"・"+ s[15]
    else
      name=s[15]+s[16]
    end
    id = s[0] + (97 + zip_counts[zip]).chr
    zip_counts[zip] += 1
    if s[5]==""
      title=s[1]
    elsif /^（.*）$/=~s[4]
      title=s[1]+s[4]
    else
      title=s[1]+"（#{s[4]}）"
    end
    puts %Q|#{id},"#{title}",#{name},#{s[9]},| +
      %Q|#{s[43]},#{s[44]},#{time},#{s[13]},text/#{txt},#{s[50]}|
  end
end
