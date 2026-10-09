#!/usr/local/rvm/rubies/ruby-3.0.2/bin/ruby
#encoding: utf-8
#cgi_org.rb

print "Content-Type: application/x-ndjson; charset=UTF-8\r\n\r\n"

require "json"
require "uri"
require "base64"

DATA = <<'EOS'
📿
EOS

hs, a001 = Marshal.load(Base64.decode64(DATA))

# 検索
def search(keyword, a001, regexp = false)
  f = ""
  begin
    pattern =
      if regexp
        Regexp.new(keyword)
      else
        Regexp.new(Regexp.escape(keyword))
      end
  rescue RegexpError => e
    raise e
  end
  a001.each_line{|line|
    if line.start_with?("💎")
      f = line[1..-1].chomp
    elsif match = pattern.match(line)
      pos = match.begin(0)
      start = [pos - 20, 0].max
      length = match[0].length + 40
      text = line[start, length].strip
      yield f, text
    end
  }
end
query = ENV["QUERY_STRING"].to_s
params = URI.decode_www_form(query).to_h
keyword = params["keyword"].to_s.strip.force_encoding("UTF-8")
regexp = params["regexp"] == "1"

begin
  last_f = nil
  work = nil
  search(keyword, a001, regexp){|f, text|
    if f != last_f
      # 前の作品を送る
      if work
        print(JSON.generate(work) + "\n")
      end
      # 新しい作品
      meta = hs[f]
      unless meta
        STDERR.puts "CSVにありません: #{f.inspect}"
        next
      end
      work = {
        "f" => f,
        "title" => meta[1].gsub(%Q<">, ""),
        "author" => meta[0],
        "card_url" => meta[2],
        "html_url" => meta[3],
        "snippets" => []
      }
      last_f = f
    end
    work["snippets"] << text
  }

  # 最後の作品を送る
  if work
    print(JSON.generate(work) + "\n")
  end
rescue => e
  File.open("ag_error.txt", "a") do |log|
    log.puts "=============================="
    log.puts Time.now
    log.puts "CGI: #{__FILE__}"
    log.puts "ERROR: #{e.class}: #{e.message}"
    log.puts e.backtrace
    log.puts "=============================="
  end
  exit
end
