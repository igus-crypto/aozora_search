#!/usr/local/rvm/rubies/ruby-3.0.2/bin/ruby
#encoding: utf-8
# search_selected.cgi

require "json"
require "uri"

# JSON形式で応答
print "Content-Type: application/json; charset=UTF-8\r\n\r\n"

begin
  # POSTデータを読み込む
  length = ENV["CONTENT_LENGTH"].to_i
  raise "POSTデータがありません" if length <= 0
  raise "POSTデータが大きすぎます" if length > 10_000_000

  request = JSON.parse(STDIN.read(length))

  keyword = request["keyword"].to_s.strip
  regexp = request["regexp"] == true
  works = request["works"]

  raise "検索語を入力してください" if keyword.empty?
  raise "検索対象が不正です" unless works.is_a?(Array)

  # 検索パターンを作る
  pattern = Regexp.new(regexp ? keyword : Regexp.escape(keyword))

  # 本文ファイルのフォルダー
  text_dir = File.expand_path("text", __dir__)

  results = []

  works.each do |work|
    next unless work.is_a?(Hash)

    # text_urlからファイル名だけを取り出す
    text_url = work["text_url"].to_s
    filename = File.basename(text_url)

    # 青空文庫テキストのファイル名だけを許可
    unless filename.match?(/\A[A-Za-z0-9_-]+\.txt\z/)
      next
    end

    path = File.expand_path(filename, text_dir)

    # textフォルダー外へのアクセスを防止
    next unless path.start_with?(text_dir + File::SEPARATOR)
    next unless File.file?(path)

    snippets = []
    hit_count = 0

    File.foreach(path, encoding: "UTF-8") do |line|
      match = pattern.match(line)
      next unless match

      hit_count += 1

      # 1作品あたり最大20件の抜粋を表示
      if snippets.length < 20
        pos = match.begin(0)
        start_pos = [pos - 20, 0].max
        length = [match.end(0) - start_pos + 40,
                  line.length - start_pos].min

        snippets << line[start_pos, length].strip
      end
    end

    # 該当箇所のある作品だけ返す
    if hit_count > 0
      results << {
        "title" => work["title"].to_s,
        "author" => work["author"].to_s,
        "text_url" => text_url,
        "card_url" => work["card_url"].to_s,
        "html_url" => work["html_url"].to_s,
        "hit_count" => hit_count,
        "snippets" => snippets
      }
    end
  end

  print JSON.generate({
    "ok" => true,
    "count" => results.length,
    "results" => results
  })

rescue RegexpError => e
  print JSON.generate({
    "ok" => false,
    "error" => "正規表現エラー: #{e.message}"
  })

rescue => e
  STDERR.puts "#{e.class}: #{e.message}"
  STDERR.puts e.backtrace
  print JSON.generate({
    "ok" => false,
    "error" => e.message
  })
end
