#! ruby
#encoding:utf-8
#make_txt.rb

require "zip"
require "fileutils"

$stderr=open("err.txt","w:utf-8")

FileUtils.mkdir_p("txt")
Dir.glob("zip/*.zip").each do |zipfile|
  dirname=File.basename(zipfile,".zip")
  dir="txt/#{dirname}"
  FileUtils.mkdir_p(dir)
  begin
    Zip::File.open(zipfile) do |zip|
      zip.each do |entry|
        next unless entry.name.downcase.end_with?(".txt")
        filename=File.basename(entry.name)
        path="#{dir}/#{filename}"
        File.binwrite(path,entry.get_input_stream.read)
        puts "#{File.basename(zipfile)} -> #{filename}"
      end
    end
  rescue=>e
    $stderr.puts "#{File.basename(zipfile)}: #{e.class}: #{e.message}"
  end
end
$stderr.close
