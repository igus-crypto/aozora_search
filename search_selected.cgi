#!/usr/local/rvm/rubies/ruby-3.0.2/bin/ruby
#encoding: utf-8
# search_selected.cgi

require "json"
require "uri"
require "tmpdir"
require "fileutils"

class SearchCancelled < StandardError; end

job_action = nil
job_dir = nil
response_header_sent = false
begin
  # POSTデータを読み込む
  length = ENV["CONTENT_LENGTH"].to_i
  raise "POSTデータがありません" if length <= 0
  raise "POSTデータが大きすぎます" if length > 10_000_000

  request = JSON.parse(STDIN.read(length))

  job_action = request["action"].to_s
  job_id = request["job_id"].to_s
  if ["start", "cancel"].include?(job_action)
    raise "検索IDが不正です" unless job_id.match?(/\A[a-f0-9]{32}\z/)
    job_dir = File.join(Dir.tmpdir, "aozora_search_#{job_id}")
    print "Content-Type: application/json; charset=UTF-8\r\n\r\n"
    response_header_sent = true
    if job_action == "start"
      Dir.mkdir(job_dir, 0700)
      print JSON.generate({ "ok" => true })
    else
      accepted = false
      if File.directory?(job_dir)
        begin
          File.write(File.join(job_dir, "cancel"), "1")
          accepted = true
        rescue Errno::ENOENT
          # 検索が先に終了して作業用フォルダーが消えた場合
        end
      end
      print JSON.generate({ "ok" => true, "accepted" => accepted })
    end
    exit
  end

  streaming = job_action == "search"
  if streaming
    print "Content-Type: application/x-ndjson; charset=UTF-8\r\n\r\n"
    STDOUT.sync = true
  else
    print "Content-Type: application/json; charset=UTF-8\r\n\r\n"
  end
  response_header_sent = true

  cancel_file = nil
  if job_action == "search"
    raise "検索IDが不正です" unless job_id.match?(/\A[a-f0-9]{32}\z/)
    job_dir = File.join(Dir.tmpdir, "aozora_search_#{job_id}")
    raise "検索ジョブが見つかりません" unless File.directory?(job_dir)
    cancel_file = File.join(job_dir, "cancel")
  end
  check_cancelled = lambda do
    raise SearchCancelled if cancel_file && File.exist?(cancel_file)
  end

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
  result_count = 0

  check_cancelled.call
  works.each do |work|
    check_cancelled.call
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
    line_number = 0

    File.foreach(path, encoding: "UTF-8") do |line|
      line_number += 1
      check_cancelled.call if (line_number % 100).zero?
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
    check_cancelled.call

    # 該当箇所のある作品だけ返す
    if hit_count > 0
      result = {
        "title" => work["title"].to_s,
        "author" => work["author"].to_s,
        "text_url" => text_url,
        "card_url" => work["card_url"].to_s,
        "html_url" => work["html_url"].to_s,
        "hit_count" => hit_count,
        "snippets" => snippets
      }
      if streaming
        print JSON.generate({ "type" => "result", "work" => result }) + "\n"
        STDOUT.flush
        result_count += 1
      else
        results << result
      end
    end
  end

  check_cancelled.call
  if streaming
    print JSON.generate({ "type" => "complete", "count" => result_count }) + "\n"
    STDOUT.flush
  else
    print JSON.generate({
      "ok" => true,
      "count" => results.length,
      "results" => results
    })
  end

rescue SearchCancelled
  print "Content-Type: application/json; charset=UTF-8\r\n\r\n" unless response_header_sent
  if job_action == "search"
    print JSON.generate({ "type" => "cancelled" }) + "\n"
    STDOUT.flush
  else
    print JSON.generate({ "ok" => true, "cancelled" => true })
  end

rescue RegexpError => e
  print "Content-Type: application/json; charset=UTF-8\r\n\r\n" unless response_header_sent
  if job_action == "search"
    print JSON.generate({
      "type" => "error",
      "error" => "正規表現エラー: #{e.message}"
    }) + "\n"
    STDOUT.flush
  else
    print JSON.generate({
      "ok" => false,
      "error" => "正規表現エラー: #{e.message}"
    })
  end

rescue => e
  STDERR.puts "#{e.class}: #{e.message}"
  STDERR.puts e.backtrace
  print "Content-Type: application/json; charset=UTF-8\r\n\r\n" unless response_header_sent
  if job_action == "search"
    print JSON.generate({ "type" => "error", "error" => e.message }) + "\n"
    STDOUT.flush
  else
    print JSON.generate({
      "ok" => false,
      "error" => e.message
    })
  end
ensure
  if job_action == "search" && job_dir && File.directory?(job_dir)
    FileUtils.remove_entry_secure(job_dir)
  end
end
