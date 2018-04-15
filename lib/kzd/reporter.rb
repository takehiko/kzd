module Kzd
  module Reporter
    def save_pstore(man, filename, ld_a = nil, dat = nil)
      ld_a ||= setup_ld(man)
      dat ||= setup_dat(man, ld_a)

      db = PStore.new(filename)
      db.transaction do
        db[:dat] = dat
      end

      dat
    end

    def setup_dat(man, ld_a)
      # man.pages[i].filename_image : 画像ファイル名
      dat = Hash.new
      dat[:size] = man.pages.length
      dat[:image] = man.pages.map {|page| page.filename_image}
      dat[:obj] = Hash.new # dat[:obj]["v:?:?"] = Kzd::Line instance; dat[:obj]["h:?:?"] = Kzd::Line instance; dat[:obj]["r:?:?"] = Kzd::Region instance
      dat[:v] = Array.new # 縦線: dat[:v][0] = [Kzd::Line instance, ...]
      dat[:h] = Array.new # 横線: dat[:h][0] = [Kzd::Line instance, ...]
      dat[:x] = Array.new # 交点: dat[:x][0] = [[crossing info], ...]
      dat[:s] = Array.new # 付随情報: dat[:s][0] = [Kzd::Region instance, ...]
      dat[:conn] = Hash.new # dat[:conn]["v:?:?"] = [["h:?:?", :cross_h], ...]; dat[:conn]["h:?:?"] = [["v:?:?", :cross_v]...]; dat[:conn]["r:?:?"] = [["v:?:?", :up_v], ...]
      dat[:r] = Array.new # 文字列: dat[:r][0] = [Kzd::Region instance, ...]
      man.each_page_with_index do |page, i|
        # 縦線
        (dat[:v][i] = ld_a[i][:ld].vertical_lines).each_with_index do |line, j|
          dat[:obj]["v:%d:%d" % [i, j]] = line
          puts "dat[:obj][\"v:#{i}:#{j}\"] = #{line}" # debug
        end

        # 横線
        (dat[:h][i] = ld_a[i][:ld].horizontal_lines).each_with_index do |line, j|
          dat[:obj]["h:%d:%d" % [i, j]] = line
          puts "dat[:obj][\"h:#{i}:#{j}\"] = #{line}" # debug
        end

        # 線の交差
        (dat[:x][i] = ld_a[i][:ld].cross_aa).each_with_index do |cross_a, j|
          key1 = "v:%d:%d" % [i, cross_a[0]]
          key2 = "h:%d:%d" % [i, cross_a[1]]
          if !dat[:conn].key?(key1)
            dat[:conn][key1] = Array.new
          end
          dat[:conn][key1] << [key2, :cross_h]
          puts "dat[:conn][\"#{key1}\"] << [\"#{key2}\", :cross_h]" # debug
          if !dat[:conn].key?(key2)
            dat[:conn][key2] = Array.new
          end
          dat[:conn][key2] << [key1, :cross_v]
          puts "dat[:conn][\"#{key2}\"] << [\"#{key1}\", :cross_v]" # debug
        end

        # 文字列
        (dat[:r][i] = man.regs(page)).each_with_index do |reg, j|
          dat[:obj]["r:%d:%d" % [i, j]] = reg
          puts "dat[:obj][\"r:#{i}:#{j}\"] = #{reg}" # debug
        end

        # 人物名と縦線
        ld_a[i][:nv].each do |reg, line, sym, pos|
          index1 = dat[:r][i].index {|reg0| reg.to_s == reg0.to_s}
          index2 = dat[:v][i].index {|line0| line.to_s == line0.to_s}
          key1 = "r:%d:%d" % [i, index1]
          key2 = "v:%d:%d" % [i, index2]
          if !dat[:conn].key?(key1)
            dat[:conn][key1] = Array.new
          end
          dat[:conn][key1] << [key2, sym == :top ? :up_v : :down_v]
          puts "dat[:conn][\"#{key1}\"] << [\"#{key2}\", #{dat[:conn][key1][-1][-1]}]" # debug
          if !dat[:conn].key?(key2)
            dat[:conn][key2] = Array.new
          end
          dat[:conn][key2] << [key1, sym == :top ? :down_r : :up_r]
          puts "dat[:conn][\"#{key2}\"] << [\"#{key1}\", #{dat[:conn][key2][-1][-1]}]" # debug
        end

        # 付随情報
        dat[:s][i] = ld_a[i][:sn] || []
        dat[:s][i].each do |reg|
          index1 = dat[:r][i].index {|reg0| reg.to_s == reg0.to_s}
          key1 = "r:%d:%d" % [i, index1]
          puts "note: #{dat[:obj][key1]}<\"#{key1}\">" # debug
        end

        # ページ間の横線
        if i > 0
          left_a = ld_a[i - 1][:oh].map {|item| (item[1] == :left || item[1] == :both) ? item : nil}.compact
          right_a = ld_a[i][:oh].map {|item| (item[1] == :right || item[1] == :both) ? item : nil}.compact
          [left_a.length, right_a.length].min.times do |j|
            index1 = dat[:h][i - 1].index {|line0| left_a[j][0].to_s == line0.to_s}
            index2 = dat[:h][i].index {|line0| right_a[j][0].to_s == line0.to_s}
            key1 = "h:%d:%d" % [i - 1, index1]
            key2 = "h:%d:%d" % [i, index2]
            if !dat[:conn].key?(key1)
              dat[:conn][key1] = Array.new
            end
            dat[:conn][key1] << [key2, :next_h]
            puts "dat[:conn][\"#{key1}\"] << [\"#{key2}\", :next_h]" # debug
            if !dat[:conn].key?(key2)
              dat[:conn][key2] = Array.new
            end
            dat[:conn][key2] << [key1, :prev_h]
            puts "dat[:conn][\"#{key2}\"] << [\"#{key1}\", :prev_h]" # debug
          end
        end
      end

      dat
    end

    def setup_ld(man, flag_return_array = false)
      # ld_a[i][:ld] : Kzd::LineDetectorインスタンス
      # ld_a[i][:ld].run_v_a : 縦線の集合 [[x, y1, x, y2], ...]
      # ld_a[i][:ld].run_h_a : 横線の集合 [[x1, y, x2, y], ...]
      # ld_a[i][:ld].vertical_lines : 縦線の集合 [Kzd::Line instance, ...]
      # ld_a[i][:ld].horizontal_lines : 横線の集合 [Kzd::Line instance, ...]
      # ld_a[i][:ld].cross_aa : 交点の集合# [[縦線の添字, 横線の添字, [交点x, 交点y]], ...]
      # ld_a[i][:nv] : 人物情報の文字列と，それにつながる縦線の組の配列 [[Kzd::Region instance, Kzd::Line instance, :topまたは:bot, [x, y]], ...]
      # ld_a[i][:sn] : 付随情報の配列 [Kzd::Region instance, ...]
      # ld_a[i][:oh] : 隣接ページとまたがる横線 [Kzd::Line instance, :leftまたは:rightまたは:both]

      ld_a = Array.new # [{:ld => ld, :nv => ld.find_name_and_vline, :oh => ld..find_outside_hline}, ...]
      stat_a = [] # 人物情報など
      man.each_page_with_index do |page, i|
        stat_a << "<#{page.key}> #{page.filename_image} #{page.filename_xml}"
        ld = page.lin

        # 人物名と縦線
        aa = ld.find_name_and_vline(40)
        aa.each do |a|
          # [Kzd::Region instance, Kzd::Line instance, :topまたは:bot, [x, y]]
          if a[2] == :top
            stat_a << "    " + "(%4d,%4d)-(%4d,%4d)" % a[1].to_a + " -- " + a[0].string + "(%4d,%4d,%4d,%4d)" % a[0].box
          else
            stat_a << "    " + " " * 27 + a[0].string + "(%4d,%4d,%4d,%4d)" % a[0].box + " -- " + "(%4d,%4d)-(%4d,%4d)" % a[1].to_a
          end
        end

        # 付随情報
        sn_aa = []
        nv_s_aa = aa.map {|item| item[0].to_s}
        ld.reg_a.each do |reg|
          if nv_s_aa.index(reg.to_s).nil?
            sn_aa << reg.dup
            stat_a << "    " + reg.string + "(%4d,%4d,%4d,%4d)" % reg.box + " : comment"
          end
        end

        # 隣接ページとまたがる横線の検出
        aa2 = ld.find_outside_hline(20, 0.1)
        aa2.sort_by! {|item| item[0].y1}
        aa2.each do |a|
          s = (a[1] == :both || a[1] == :left) ? "<" : "-"
          s += "--- "
          s += "(%4d,%4d)-(%4d,%4d)" % a[0].to_a
          s += " ---"
          s += (a[1] == :both || a[1] == :right) ? ">" : "-"
          stat_a << s
        end

        ld_a[i] = {:ld => ld, :nv => aa, :sn => sn_aa, :oh => aa2}
      end

      flag_return_array ? [ld_a, stat_a] : ld_a
    end

    def report_all(dat, filename)
      f_out = open(filename, "w")

      # 基本情報
      f_out.puts_for_reporter("directory: #{dat[:image][0].split(/\//)[0]}")
      f_out.puts_for_reporter("number of image: #{dat[:size]}")
      f_out.puts_for_reporter("number of object: #{dat[:obj].size}")
      f_out.puts_for_reporter("number of string: #{dat[:r].map {|item| item.size}.inject(:+)}")
      f_out.puts_for_reporter("number of vertical line: #{dat[:v].map {|item| item.size}.inject(:+)}")
      f_out.puts_for_reporter("number of horizontal line: #{dat[:h].map {|item| item.size}.inject(:+)}")
      f_out.puts_for_reporter

      # 文字列，縦線，横線の情報
      keys_a = []
      ["r", "v", "h"].each do |obj_type|
        keys = dat[:obj].keys.delete_if {|item| item[0, 1] != obj_type}.sort_for_reporter
        keys.each do |key|
          if dat[:conn].key?(key)
            reg_or_line = dat[:obj][key]
            s = (obj_type == "r") ? reg_or_line.string : reg_or_line.to_s
            f_out.puts_for_reporter("#{s}<#{key}>: #{dat[:conn][key].inspect}")
          end
        end
        f_out.puts_for_reporter

        keys_a << keys
      end
      keys_r, keys_v, keys_h = keys_a

      # 交点
      dat[:x].each_with_index do |cross_aa, i|
        next if dat[:x][i].empty?
        dat[:x][i].each do |cross_a|
          key1 = "v:#{i}:#{cross_a[0]}"
          key2 = "h:#{i}:#{cross_a[1]}"
          point = "(%d,%d)" % cross_a[2]
          f_out.puts_for_reporter("intersection : #{point}<#{key1}>-<#{key2}>")
        end
      end
      f_out.puts_for_reporter

      # 付随情報
      dat[:size].times do |i|
        keys = dat[:s][i].map {|reg|
          index1 = dat[:r][i].index {|reg0| reg.to_s == reg0.to_s}
          if index1
            "r:%d:%d" % [i, index1]
          else
            nil
          end
        }.compact
        keys.each do |key|
          reg = dat[:obj][key]
          s = reg.string
          f_out.puts_for_reporter("note: #{s}<#{key}>")
        end
      end
      f_out.puts_for_reporter

      # 親子関係
      parent_child_h = Hash.new # {key_of_parent => [key_of_child, ...]}
      child_parent_h = Hash.new # {key_of_child => [key_of_parent, ...]}
      keys_r.each do |keyp|
        # regp = dat[:obj][keyp]
        next if !dat[:conn].key?(keyp)

        # 深さ優先探索で子を探す
        node_a = dat[:conn][keyp].map {|item| item[1] == :down_v ? item : nil}.compact # [[key, sym], ...]; delete_ifは破壊的メソッドのため使用しない
        key_visited = [keyp]
        until node_a.empty?
          node = node_a.shift
          key, sym = node
          key_visited << key
          if key[0] == "r"
            parent_s = "#{dat[:obj][keyp].string}<#{keyp}>"
            child_s = "#{dat[:obj][key].string}<#{key}>"
            f_out.puts_for_reporter("parent-child : #{parent_s}-#{child_s}")
            if parent_child_h[keyp].nil?
              parent_child_h[keyp] = []
            end
            parent_child_h[keyp] << key
            if child_parent_h[key].nil?
              child_parent_h[key] = []
            end
            child_parent_h[key] << keyp
          elsif dat[:conn].key?(key)
            next_node_a = dat[:conn][key].map {|item| key_visited.index(item[0]) ? nil : item}.compact # delete_ifは破壊的メソッドのため使用しない
            node_a += next_node_a
            node_a.uniq!
          end
        end
      end
      f_out.puts_for_reporter

      # 兄弟関係（2者）
      sibling_h = Hash.new # {key_of_person => [key_of_sibling_person, ...]}
      keys_r.each do |keyp|
        next if !dat[:conn].key?(keyp)

        # 深さ優先探索で子を探す
        node_a = dat[:conn][keyp].map {|item| item[1] == :up_v ? item : nil}.compact # [[key, sym], ...]; delete_ifは破壊的メソッドのため使用しない
        key_visited = [keyp]
        until node_a.empty?
          node = node_a.shift
          key, sym = node
          key_visited << key
          if key[0] == "r"
            person1 = "#{dat[:obj][keyp].string}<#{keyp}>"
            person2 = "#{dat[:obj][key].string}<#{key}>"
            if child_parent_h.key?(keyp) && child_parent_h[keyp].index(key)
              puts  "skip : #{person1}-#{person2}"
            else
              f_out.puts_for_reporter("sibling : #{person1}-#{person2}")
              if sibling_h[keyp].nil?
                sibling_h[keyp] = []
              end
              sibling_h[keyp] << key
            end
          elsif dat[:conn].key?(key)
            next_node_a = dat[:conn][key].map {|item| key_visited.index(item[0]) ? nil : item}.compact # delete_ifは破壊的メソッドのため使用しない
            node_a += next_node_a
            node_a.uniq!
          end
        end
      end
      f_out.puts_for_reporter

      # 兄弟関係（グループ化，sibling_h使用）
      key_checked = Hash.new
      sibling_h.keys.sort_for_reporter.each do |key|
        next if key_checked.key?(key)
        a = ([key] + sibling_h[key]).sort_for_reporter
        f_out.puts_for_reporter("sibling group : #{a.length} persons : " + a.map {|key| "#{dat[:obj][key].string}<#{key}>"}.join(", "))
        a.each do |key|
          key_checked[key] = true
        end
      end

      f_out.close
    end
  end
end

class IO
  def puts_for_reporter(s = "")
    $stdout.puts s
    if self != $stdout
      self.print s + "\r\n"
    end
  end
end

class Array
  def sort_for_reporter
    sort_by {|item|
      a = item.split(":")
      "%s:%04d:%04d" % [a[0], a[1].to_i, a[2].to_i]
    }
  end
end
