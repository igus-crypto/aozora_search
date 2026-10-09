#! ruby
#encoding:utf-8
#get_zip.rb

require "open-uri"
require "fileutils"

$stderr=open("err.txt","w:utf-8")

FileUtils.mkdir_p("zip")

urls=File.readlines("zip_urls.txt",chomp:true)

urls.each_with_index do |url,i|
  filename=File.basename(URI.parse(url).path)
  path="zip/#{filename}"
  begin
    URI.open(url,open_timeout:10,read_timeout:30) do |f|
      File.binwrite(path,f.read)
    end
    puts "#{i+1}/#{urls.size} #{filename}"
  rescue=>e
    $stderr.puts "#{url}\t#{e.message}"
    puts "ERROR #{url}"
  end
end
