#!/usr/local/rvm/rubies/ruby-3.0.2/bin/ruby
#encoding: utf-8
# search_selected.cgi

require "json"
require "uri"
require "tmpdir"
require "fileutils"
require "tempfile"

class SearchCancelled < StandardError; end

UGREP_PATH = ENV.fetch("AOZORA_UGREP_PATH", "/virtual/pansy/local/bin/ugrep")
SEARCH_BATCH_SIZE = 1024

def work_filename(work)
  return unless work.is_a?(Hash)

  filename = File.basename(work["text_url"].to_s)
  filename if filename.match?(/\A[A-Za-z0-9_-]+\.txt\z/)
end

def ugrep_candidates(keyword, filenames, text_dir, check_cancelled)
  return {} if filenames.empty?

  # -l は最初の一致で次のファイルへ進む。-J1 は検索の並列化を無効にする。
  paths = filenames.map { |filename| "./#{filename}" }
  Tempfile.create("aozora_ugrep", binmode: true) do |output|
    pid = Process.spawn(
      UGREP_PATH, "--no-config", "--color=never", "-J1", "-a", "-F", "-l", "-0",
      "-e", keyword, "--", *paths, chdir: text_dir, in: File::NULL, out: output
    )
    status = nil
    begin
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
      loop do
        check_cancelled.call
        finished = Process.waitpid2(pid, Process::WNOHANG)
        if finished
          pid = nil
          status = finished.last.exitstatus
          raise "ugrepの検索に失敗しました（終了コード #{status || 'signal'}）" unless [0, 1].include?(status)

          break
        end
        raise "ugrepの検索がタイムアウトしました" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.025
      end
    ensure
      if pid
        begin
          Process.kill("KILL", pid)
        rescue Errno::ESRCH
          # 中断と同時にugrepが終了した場合
        ensure
          Process.waitpid(pid)
        end
      end
    end

    check_cancelled.call
    output.rewind
    matches = output.read.split("\0")
    # 想定外の出力を一致なしとして扱わない。
    unless (matches - paths).empty? && (status == 1) == matches.empty?
      raise "ugrepの検索結果の形式が正しくありません"
    end

    matches.to_h { |path| [path.delete_prefix("./"), true] }
  end
rescue Errno::ENOENT, Errno::EACCES => e
  STDERR.puts e.message
  raise "ugrepを起動できませんでした"
end

job_action = nil
job_dir = nil
response_header_sent = false
STDIN.binmode
STDOUT.binmode
begin
  cgi_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  # POSTデータを読み込む
  length = ENV["CONTENT_LENGTH"].to_i
  raise "POSTデータがありません" if length <= 0
  raise "POSTデータが大きすぎます" if length > 10_000_000

  request = JSON.parse(STDIN.read(length))

  job_action = request["action"].to_s
  job_id = request["job_id"].to_s
  if ["search", "cancel"].include?(job_action)
    raise "検索IDが不正です" unless job_id.match?(/\A[a-f0-9]{32}\z/)
    path = File.join(Dir.tmpdir, "aozora_search_#{job_id}")
    if job_action == "cancel"
      accepted = false
      begin
        File.write(File.join(path, "cancel"), "1")
        accepted = true
      rescue Errno::ENOENT
        # 検索の開始前、または終了後
      end
      print "Content-Type: application/json; charset=UTF-8\r\n\r\n"
      response_header_sent = true
      print JSON.generate({ "ok" => true, "accepted" => accepted })
      exit
    end
    Dir.mkdir(path, 0700)
    job_dir = path
  end

  keyword = request["keyword"].to_s.strip
  regexp = request["regexp"] == true
  works = request["works"]
  # ugrepの固定文字列は改行で分割され、先頭のUTF-8 BOMは読み飛ばされる。
  use_ugrep = !regexp && !keyword.match?(/[\n\r\0\uFEFF]/)
  streaming = job_action == "search"
  content_type = streaming ? "application/x-ndjson" : "application/json"
  print "Content-Type: #{content_type}; charset=UTF-8\r\n"
  print "X-Aozora-Search-Engine: #{use_ugrep ? 'ugrep' : 'ruby'}\r\n\r\n"
  STDOUT.sync = true if streaming
  response_header_sent = true

  cancel_file = File.join(job_dir, "cancel") if job_dir
  check_cancelled = lambda do
    raise SearchCancelled if cancel_file && File.exist?(cancel_file)
  end

  raise "検索語を入力してください" if keyword.empty?
  raise "検索対象が不正です" unless works.is_a?(Array)

  # 検索パターンを作る
  pattern = Regexp.new(regexp ? keyword : Regexp.escape(keyword))

  # 本文ファイルのフォルダー
  text_dir = File.expand_path("text", __dir__)

  results = []
  result_count = 0

  profiling = streaming && request["profile"] == true
  ugrep_runs = 0
  ugrep_time = 0.0
  ruby_time = 0.0
  search_files = 0

  check_cancelled.call
  works.each_slice(SEARCH_BATCH_SIZE) do |batch|
    check_cancelled.call
    filenames = batch.map { |work| work_filename(work) }
    if use_ugrep
      available = filenames.compact.uniq.select do |filename|
        File.file?(File.join(text_dir, filename))
      end
      ugrep_started = Process.clock_gettime(Process::CLOCK_MONOTONIC) if profiling && !available.empty?
      candidates = ugrep_candidates(keyword, available, text_dir, check_cancelled)
      if profiling && !available.empty?
        ugrep_time += Process.clock_gettime(Process::CLOCK_MONOTONIC) - ugrep_started
        ugrep_runs += 1
        search_files += available.length
      end
    end

    batch.zip(filenames).each do |work, filename|
      check_cancelled.call
      next unless filename
      next if use_ugrep && !candidates.key?(filename)

      path = File.join(text_dir, filename)
      next unless File.file?(path)

      text_url = work["text_url"].to_s

      snippets = []
      hit_count = 0
      line_number = 0

      ruby_started = Process.clock_gettime(Process::CLOCK_MONOTONIC) if profiling
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

      ruby_time += Process.clock_gettime(Process::CLOCK_MONOTONIC) - ruby_started if profiling

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
  end

  check_cancelled.call
  if streaming
    event = { "type" => "complete", "count" => result_count }
    if profiling
      event["profile"] = {
        "cgi_ms" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - cgi_started) * 1000).round(2),
        "ugrep_ms" => (ugrep_time * 1000).round(2),
        "ruby_scan_ms" => (ruby_time * 1000).round(2),
        "ugrep_runs" => ugrep_runs,
        "ugrep_files" => search_files
      }
    end
    print JSON.generate(event) + "\n"
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
