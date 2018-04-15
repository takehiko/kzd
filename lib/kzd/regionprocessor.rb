module Kzd
  class RegionProcessor
    def initialize(filename = nil)
      @filename_in = filename
      @pcidx = Hash.new {Array.new} # 値の意味はcorrespond_person_commentを参照
      @cpidx = Hash.new
    end
    attr_reader :filename_in, :doc, :tagreg
    attr_reader :pcidx, :cpidx
    # 文字列領域（Kzd::Region）の配列への操作に関して，
    # メソッドstringsおよびstrings=を定義している

    def analyze
      # REXMLを使用せずに領域情報を読み出す
      @tagreg = {"String" => [], "Symbol" => []}

      open(@filename_in) do |f_in|
        flag_read_symbol = false
        reg = nil
        f_in.each_line do |line|
          if /String/i =~ line
            if !(reg = str_to_reg(line)).nil?
              if /content\s*[=:]?\s*\"?([^\"]+)/i =~ line
                reg.string = $1
              end
              @tagreg["String"] << reg
              reg = nil
            end
            flag_read_symbol = false
          elsif /Symbol/i =~ line
            if !(reg = str_to_reg(line)).nil?
              flag_read_symbol = true
            end
          elsif flag_read_symbol
            if /Variant/i =~ line && /VS\s*[=:]?\s*\"?([^\"]+)/i =~ line
              reg.string = $1
              @tagreg["Symbol"] << reg
              reg = nil
            end
            flag_read_symbol = false
          end
        end
      end

      refresh_person_comment

      self
    end

    def str_to_reg(s)
      # 'WIDTH="111" HEIGHT="178" HPOS="1032" VPOS="122"'のような
      # 文字列から，Regionインスタンスを生成する

      h = {}
      attr_a = %w(hpos height vpos width)

      attr_a.each do |attr|
        if /#{attr}\s*[=:]?\s*\"?(\d+)/i =~ s
          h[attr.to_sym] = $1
        end
      end

      attr_a.each do |attr|
        return nil if !h.key?(attr.to_sym)
      end

      Region.new(h)
    end

    def export_region(option_print_result = true)
      @tagreg.each_key do |tagname|
        filename_out = @filename_in.sub(/\.xml$/i, "") + "_#{tagname}.txt"
        puts "save as #{filename_out}..." if option_print_result
        open(filename_out, "w") do |f_out|
          @tagreg[tagname].each do |reg|
            f_out.print (reg.box(:descrete => true) + [reg.string]).join(",")
            f_out.print "\r\n"
          end
        end
      end
    end

    def start(option_print_result = true)
      analyze(option_print_result)
      export_region(option_print_result)
      self
    end

    def set_person(option_force = false)
      each_string do |reg|
        if option_force || !reg.comment?
          reg.set_person
        end
      end
      refresh_person_comment
      self
    end

    def set_comment(option_force = false)
      each_string do |reg|
        if option_force || !reg.person?
          reg.set_comment
        end
      end
      refresh_person_comment
      self
    end

    def set_by_regexp(type, regexp, option_force = false)
      each_string do |reg|
        next if !option_force && (reg.person? || reg.comment?)
        if regexp =~ reg.string
          reg.send("set_#{type}")
        end
      end
      refresh_person_comment
      self
    end

    def set_person_by_regexp(regexp, option_force = false)
      set_by_regexp("person", regexp, option_force)
    end

    def set_comment_by_regexp(regexp, option_force = false)
      set_by_regexp("comment", regexp, option_force)
    end

    def set_unidentified_by_regexp(regexp, option_force = false)
      set_by_regexp("unidentified", regexp, option_force)
    end

    def set_by_size(type, box, option_force = false)
      each_string do |reg|
        next if !option_force && (reg.person? || reg.comment?)
        if box[0] <= reg.width && reg.width <= box[2] &&
            box[1] <= reg.height && reg.height <= box[3]
          reg.send("set_#{type}")
        end
      end
      refresh_person_comment
      self
    end

    def set_person_by_size(box, option_force = false)
      set_by_size("person", box, option_force)
    end

    def set_comment_by_size(box, option_force = false)
      set_by_size("comment", box, option_force)
    end

    def refresh_person_comment
      @person_idx_a = []
      @comment_idx_a = []
      strings.each_with_index do |reg, i|
        if reg.person?
          @person_idx_a << i
        end
        if reg.comment?
          @comment_idx_a << i
        end
      end
      self
    end

    def correspond_person_comment
      @pcidx = Hash.new  {Array.new}
      # @pcidx[i]の値は，
      # * @tagreg["String"][i].person?が真のときは，
      #   @tagreg["String"][i]（人物名）に対応づけられる付随情報の
      #   インデックスj（@tagreg["String"][j]は付随情報）の配列
      # * @tagreg["String"][i].person?が偽のときは，空配列
      @cpidx = Hash.new
      # @cpidx[i]の値は，
      # * @tagreg["String"][i].comment?が真のときは，
      #   @tagreg["String"][i]（付随情報）に対応づけられる人物名の
      #   インデックスj（@tagreg["String"][j]は人物名）
      # * @tagreg["String"][i].comment?が偽のときは，nil
      strings.each_with_index do |reg, i|
        next if !reg.comment?
        x1, y1 = reg.centertop
        j_min = -1
        dist_min = -1
        strings.each_with_index do |reg2, j|
          next if !reg2.person?
          x2, y2 = reg2.centertop
          dist = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
          if j_min == -1 || dist < dist_min
            j_min = j
            dist_min = dist
          end
        end
        puts "#{@tagreg['String'][j_min].string} - #{reg.string}" if $DEBUG
        puts "  @tagreg[\"String\"][#{j_min}] - @tagreg[\"String\"][#{i}]" if $DEBUG
        if !@pcidx.key?(j_min)
          @pcidx[j_min] = [i]
        else
          @pcidx[j_min] << i
        end
        @cpidx[i] = j_min
      end

      self
    end

    def all_person_idx
      @person_idx_a
    end

    def all_person_reg
      all_person_idx.map {|i| strings[i]}
    end
    alias :all_person :all_person_reg

    def each_person
      all_person_reg.each do |reg|
        yield(reg)
      end
    end

    def all_comment_idx
      @comment_idx_a
    end

    def all_comment_reg
      all_comment_idx.map {|i| strings[i]}
    end
    alias :all_comment :all_comment_reg

    def each_comment
      all_comment_reg.each do |reg|
        yield(reg)
      end
    end

    def strings
      @tagreg["String"]
    end
    alias :string_a :strings

    def strings=(a)
      @tagreg["String"] = a
      refresh_person_comment
      a
    end
    alias :string_a= :strings=

    def each_string
      strings.each do |reg|
        yield(reg)
      end
    end
    alias :each_region :each_string

    def each_string_with_index
      strings.each_with_index do |reg, i|
        yield(reg, i)
      end
    end
    alias :each_region_with_index :each_string_with_index

    def all_unidentified_idx
      (0...(strings.length)).to_a - @person_idx_a - @comment_idx_a
    end

    def all_unidentified_reg
      all_unidentified_idx.map {|i| strings[i]}
    end
    alias :all_unidentified :all_unidentified_reg

    def each_unidentified
      all_unidentified_idx.map {|i| strings[i]}.each do |reg|
        yield(reg)
      end
    end

    def search_by_string(s, flag_find_first = false)
      # 第1引数と一致するKzd::Regionインスタンスの配列を返す（なければ空配列）
      # 第2引数が真のときは配列の先頭（ない場合にはnil）を返す
      a = strings.map {|reg| s === reg.string ? reg : nil}.compact
      flag_find_first ? a : a.first
    end
    alias :search_by_name :search_by_string

    def reg_idx(reg)
      each_string_with_index do |reg2, i|
        return i if reg.object_id == reg2.object_id
      end
      nil
    end

    def search_idx(param)
      return reg_idx(param) if Kzd::Region === param
      param = param.to_s
      each_string_with_index do |reg2, i|
        return i if param.to_s == reg2.string
      end
      nil
    end

    def set_person_comment(param_p, param_c)
      if Numeric === param_p
        idx_p = param_p
      else
        idx_p = search_idx(param_p)
      end
      if Numeric === param_c
        idx_c = param_c
      else
        idx_c = search_idx(param_c)
      end
      return false if idx_p.nil? || idx_c.nil?

      puts "set_person_comment: #{strings[idx_p].string} - #{strings[idx_c].string}" if $DEBUG

      @cpidx[idx_c] = idx_p
      if !@pcidx.key?(idx_p)
        @pcidx[idx_p] = [idx_c]
      else
        @pcidx.each_key do |idx_p2|
          @pcidx[idx_p2] -= [idx_c]
        end
        @pcidx[idx_p] << idx_c
      end
      self
    end

    def modify_region_type(param = {})
      dist = param[:dist]
      distx = (param[:distx] || dist || 50).to_i # 同列と見なすX座標の差の最大値
      disty = (param[:disty] || dist || 50).to_i # 同行と見なすY座標の差の最大値
      vote_min = (param[:vote] || 1).to_i # 変更する票差の最小値

      vote_a = [] # [[近いpersonの数, 近いcommentの数], ...]
      each_string_with_index do |reg1, i|
        count_person = count_comment = 0
        center1, top1 = reg1.centertop
        each_string_with_index do |reg2, j|
          next if i == j
          next if reg2.unidentified?
          # 近さに応じた処理
          center2, top2 = reg2.centertop
          if (center1 - center2).abs <= distx || (top1 - top2).abs <= disty
            count_person += 1 if reg2.person?
            count_comment += 1 if reg2.comment?
          end
        end
        vote_a << [count_person, count_comment]
      end

      each_string_with_index do |reg, i|
        # 差がvote_min以上あれば変更
        if reg.person? && vote_a[i][1] - vote_a[i][0] >= vote_min
          puts "#{reg.string} is set as comment" if $DEBUG
          reg.set_comment
        elsif reg.comment? && vote_a[i][0] - vote_a[i][1] >= vote_min
          puts "#{reg.string} is set as person" if $DEBUG
          reg.set_person
        end
      end
      self
    end
  end
end
