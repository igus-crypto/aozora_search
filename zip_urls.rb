#! ruby
#encoding:utf-8
#zip_urls.rb

s=File.read("list_person_all_extended_utf8.csv")
urls=s.scan(%r|http[^"]*\.zip|).uniq.sort
File.write("zip_urls.txt",urls.join("\n"))

