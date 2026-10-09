#ruby
#encoding:utf-8
#ao_edit.rb

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

##cmd確認用
#if RUBY_PLATFORM =~ /mingw32/
#  $stdout=open("tmp.txt","w")
#  $stderr=open("tmp_err.txt","w")
#  require "./data01.rb"
#  require "./data02.rb"
#  HAS,TRI,REP02=DATA2
#end

REP01,PAT,AR01,AR02,AR03,AR04,AR12,AR13,AR14,AR15,
  RE01,RE02,RE03,RE04,RE05,RE06,RE07,RE08,RE09,RE10,RE11,RE12,RE13,RE14,
  ST01,ST02,ST03,ST04,ST05,ST06,ST07,ST08,ST09,ST10,ST11,ST12,ST13=DATA1

class String
  def gsub_ex
    text,mes=self,0
    HAS.each{|key,value|
      n=key[0][0]+key[0][2..-1]
      if n=="p1a" && mes==0
        STDOUT.puts "直接置換完了"
        mes=1
      end
      before=PAT[n][0]+key[1]
      after =PAT[n][1]+key[2]
      hash=value.map{|k,v| [k,v.gsub(RE01,ST01)]}.to_h
      tkey=TRI[key]
      pattern=Regexp.new(before+"("+tkey+")"+after)
      text=text.gsub(pattern){|m| ST02+hash[m]}
      text=text.gsub(RE02,ST02).
        gsub(RE03,ST03).gsub(ST02,"")
      }
    text
  end
end

def ruby_remove(text)
  text = text.force_encoding("UTF-8")
  text = text.gsub(RE13,"") #"《[^》]*》"
  # "｜"除去
  text = text.gsub(ST13,"") #"｜"
  text
end

# ルビ展開
def ruby_expand(text)
  text = text.force_encoding("UTF-8")
  #AR12.each{|e|
  #  re=Regexp.new(e[0])
  #  text=text.gsub(re,e[1])}
  #print "AR12=";p text
  # ｜対象文字《ルビ》
  text = text.gsub(RE11){$2}
  # 対象文字《ルビ》
  text = text.gsub(RE12){$2}
  text
end

#直接置換（旧字変換）
def kyuuji(text)
  text = text.force_encoding("UTF-8")
  rep01a,rep01b=REP01.partition{|k,v|
    k.size==1 || (k.size==2 && k.end_with?(ST08,ST09) || RE10=~k)
  }.map(&:to_h)
  re01b=Regexp.union(rep01b.keys.sort_by{|s|-s.length})
  text=text.gsub(Regexp.union(rep01a.keys)){|m| rep01a[m]}.
    gsub(re01b){|m| rep01b[m]}
  #簡易変換
  text=simple_convert(text)
  text
end

def convert(text)
  text=text.force_encoding("UTF-8")
  STDOUT.puts "作業開始"
  # 置換前の処理
  text="\n"+text
  text.gsub!(%r|\r\n|,"\n")
  text.gsub!(%r|^-{5,}\n.*?\n-{5,}\n|m,"")
  #注釈除去
  #（　＊）のみの行を空行に
  AR02.each{|e|
    text.gsub!(e[0],e[1])}
  text.gsub!(RE06){$1*$&.length}
  text.gsub!(RE07){$1+$1.tr(ST04,ST05)}
  STDOUT.puts "注釈の除去完了"
  #旧字変換
  text=kyuuji(text)
  AR03.each{|e|
    re=Regexp.new(e[0])
    text.gsub!(re,e[1])}
  #ルビ除去
  text.gsub!(RE08){|m|
    o,r=$1,$2
    t=REP02[[o,r]]
    if t
      t=t.force_encoding("UTF-8")
      a=o+ST06+t+ST07
    else
      m
    end
  }
  AR01.each{|e|
    re=Regexp.new(e[0])
    text.gsub!(re,e[1])}
  text.gsub!(RE04){|e|
    if m = e.match(RE09)
      #STDOUT.puts "e=";p e
      key = m.captures.map(&:to_i)
      gaiji[key] || e
    else
      e
    end
  }
  STDOUT.puts "ルビの除去完了"
  text=text.gsub_ex
  STDOUT.puts "正規表現の置換完了"
  #漢数字変換
  #text=number_convert(text)
  #簡易変換
  text=simple_convert(text)
end

def number_convert(text)
  text=text.force_encoding("UTF-8")
  text.gsub(Regexp.new(AR04[0])){|e|
    e.tr(AR04[1],AR04[2])}
end

def simple_convert(text)
  text=text.force_encoding("UTF-8")
  AR14.each{|e|
    re=Regexp.new(e[0])
    text=text.gsub(re,e[1])}
  #print "AR14=";p text
  AR03.each{|e|
    re=Regexp.new(e[0])
    text=text.gsub(re,e[1])}
  #print "AR03=";p text
  AR13.each{|e|
    text=text.gsub(e[0],e[1])}
  #print "AR13=";p text
  # 出力
  if text.lines[0].include?(ST12)
    text
  else
    ST12+"\n"+text
  end
end

# リスト確認用の並べ替え
def list_sort(arr)
  a=arr.uniq.map{|row| row.join(",")}
  a1,a2=a.map{|e|
    %r|,[a-z0-9]+$|=~e ? e : e+",p0"
  }.partition{|e|
    %r|,f$|=~e
  }
  s1=a1.group_by{|x| x.count(",")}.map{|_,a|
    a.sort_by{|x|
      b=x.split(",")
      [-b[0].length,-b[1].length,b[0]]
    }.join("\n")
  }.join("\n\n")
  s2=a2.group_by{|x| x.split(",")[2]}.sort.map{|_,a|
    a.sort_by{|x|
      b=x.split(",")
      [-b[0].length,-b[1].length,b[0]]
    }.join("\n")
  }.join("\n\n").gsub(",p0","")
  $list_sort_f=s1
  $list_sort_normal=s2
  nil
end

#リストによる置換
def list_replace(text,list)
  text=text.force_encoding("UTF-8")
  # fオプションをsオプションの置換形式に変換
  list=list.map{|row|
    if row[-1]=="f"
      if row.length==3
        before,ruby,_=row
        ["｜?"+before+"《"+ruby+"》",before,"p18"]
      elsif row.length==4
        before,ruby,new_ruby,_=row
        [before+"《"+ruby+"》",before+"《"+new_ruby+"》","s"]
      else
        row
      end
    else
      row
    end
  }
  list.each{|row|
    before,after,opt=row
    next if before.nil? || before==""
    before=before.force_encoding("UTF-8")
    after=after.force_encoding("UTF-8")
    if opt.nil? || opt=="n"
      if after.end_with?(ST07) #"》"
        pat="n1b"
      else
        pat="n1a"
      end
      pre,post=PAT[pat]
      re=Regexp.new(pre+before+post)
      text=text.gsub(re){ST10+after+ST11} #"✦","✧"
    # 単純置換
    elsif opt=="s"
      text=text.gsub(before){ST10+after+ST11}
    # p1～p8
    elsif opt.match?(/\Ap[0-9]*[1-8]\z/)
      num="p"+opt[-1]
      if %w[p1 p8].include?(num)
        if after.end_with?(ST07) && before.match?(RE14) #"》","[一-龯々〇｜]$"
          pat=num+"a"
        elsif after.end_with?(ST07)
          pat=num+"b"
        else
          pat=num+"c"
        end
      elsif num=="p2" || num=="p5" || num=="p6" || num=="p7"
        if after.end_with?(ST07) && before.match?(RE14)
          pat=num+"a"
        else
          pat=num+"b"
        end
      else
        pat=num+"a"
      end
      pre,post=PAT[pat]
      re=Regexp.new(pre+before+post)
      text=text.gsub(re){ST10+after+ST11}
    end
  }
  #text
  ruby_expand(text)
end

#青空変換
def ao_convert(text)
  STDOUT.puts "青空変換実施中"
  text=text.force_encoding("UTF-8")
  if !text.include?(ST10) && !text.include?(ST11)
    text=text.gsub(%r|(.{18150}.*?)(?=\n)|m,"\\1"+ST10)
    text=ST11+text+ST10
  end
  m=text.match(%r|\A(.*#{ST11})(.*?#{ST10})(.*)\z|m)
  unless m
    STDOUT.puts "青空変換実施済み"
    return text
  end
  m1=m[1].gsub(ST11,"")
  m2=m[2].gsub(ST10,"")
  m3=m[3]
  #print "m1=";p m1
  #print "m2=";p m2
  #print "m3=";p m3
  m2=convert(m2)+ST11
  text=m1+m2+m3
end

##cmd確認用
#if RUBY_PLATFORM =~ /mingw32/
#  text=open("mujintou2.txt").read
#  text=ao_convert(text)
#  puts text
#end
