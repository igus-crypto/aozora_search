#!ruby
#encoding:utf-8
#grep_csv.rb

$stdout=open("ao_grep.csv","w")
$stderr = open("tmp_err.txt","w")

File.foreach("ao_search.csv"){|line|
  a=line.chomp.split(%r|,(?! )|)
  puts a[8].gsub("text/","")+","+a[2]+","+a[1]+","+a[7]+","+a[9]
}
