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

# zipごとにlist_personを分類
works=Hash.new{|h,k| h[k]=[]}

File.foreach("list_person_all_extended_utf8.csv",encoding:"UTF-8"){|line|
  times.each_key{|zip|
    works[zip] << line if line.include?(zip)
  }
}

# CSVを作成
times.each{|zip,(txt,time)|
  works[zip].each_with_index{|line, i|
    s=CSV.parse_line(line)
    if /^[ァ-ヴー・]+$/=~s[15] + s[16]
      name=s[16] +"・"+ s[15]
    else
      name=s[15]+s[16]
    end
      id=s[0]+(i+97).chr
      #id=s[0]
    if s[5]==""
      title=s[1]
    elsif /^（.*）$/=~s[4]
      title=s[1]+s[4]
    else
      title=s[1]+"（#{s[4]}）"
    end
    puts %Q|#{id},"#{title}",#{name},#{s[9]},| +
      %Q|#{s[43]},#{s[44]},#{time},#{s[13]},text/#{txt},#{s[50]}|
  }
}
