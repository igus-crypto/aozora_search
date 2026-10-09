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
