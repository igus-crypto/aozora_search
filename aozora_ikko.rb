#!ruby
#encoding: utf-8
#aozora_ikko.rb

$stdout=open("aozora_all.txt","w")
$stderr=open("tmp_err.txt","w")

s=File.read("list_person_all_extended_utf8.csv")
urls=s.scan(%r|http[^"]*\.zip|).uniq.map{|e| File.basename(e, ".*")}
urls.each{|dir|
  f=Dir.glob("txt/#{dir}/*.txt").first
  next unless f
  begin
    puts "💎#{dir}.txt\n"
    puts File.read(f,encoding:"CP932:UTF-8").gsub(/\r/,"")
  rescue
    $stderr.puts f
  end
}

