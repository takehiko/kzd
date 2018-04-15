module Kzd
  class LineDetector
    include Kzd::FilenameHelper
    include Kzd::LineModifier

    def initialize(opt = {})
      @img_in = opt[:img]
      @xml_in = opt[:xml]
      @reg_a = opt[:reg] # [Kzd::Region instace, ...]

      @option_do_all = opt[:all]
      @option_draw_image = opt[:draw]
      @option_save_csv = opt[:csv]
      @option_draw_on_base = opt[:draw_base]
      @option_save_by_dir = opt[:fndir]
      @mono_threshold = (opt[:mono_th] || 0.65).to_f
      @run_min = (opt[:run_len] || 25).to_i
      @bbox = opt[:bbox]
      @run_out_ratio = (opt[:run_out] || 0.04).to_f; setup_bbox
      @merge_margin = opt[:merge_margin]
      @merge_vertical_ratio = (opt[:merge_v_ratio] || 0.01).to_f
      @merge_horizontal_ratio = (opt[:merge_h_ratio] || 0.01).to_f
      @cross_tolerance = (opt[:tolerance] || 20).to_i

      @prefix = @img_in.sub(/\.je?pg$/i, "") + "_"
      @va = [] # [Kzd::Line instance, ...] 縦線分
      @ha = [] # [Kzd::Line instance, ...] 横線分
      @xaa = [] # [[縦線の添字, 横線の添字, [交点x, 交点y]], ...] 交点
      @conn_aa = [] # [[縦線の添字, 横線の添字, ...]] ページ内の線分の連結
    end
    attr_accessor :img_in, :xml_in, :reg_a, :bbox
    attr_reader :option_do_all, :option_draw_image, :option_save_csv, :option_draw_on_base
    attr_reader :mono_threshold, :run_min, :run_out_ratio
    attr_reader :prefix
    attr_accessor :ha, :va, :xaa
    alias :cross_aa :xaa
    alias :cross_aa= :xaa=
    attr_reader :conn_aa

    def start
      raise if @img_in.nil?
      raise if @xml_in.nil? && @reg_a.nil?

      if !test(?f, fn(2, :pbm)) || @option_do_all
        # 画像から「XMLファイルのString部分」「@bbox領域外」を削除
        mask(img_from: @img_in, img_to: fn(1, :jpg))

        # PPM形式の2値モノクロ画像に変換
        make_bw_image(img_from: fn(1, :jpg), img_to: fn(2, :pbm))

        # JPEG形式等に変換
        do_convert(img_from: fn(2, :pbm), img_to: fn(2, :jpg))
      end

      # 縦方向に走査
      detect_vertical_run(fn(2, :pbm))
      draw_vertical_run(fn(2, :jpg), fn(4, "V.jpg"), @img_in) if @option_draw_image

      # 横方向に走査
      detect_horizontal_run(fn(2, :pbm))
      draw_horizontal_run(fn(2, :jpg), fn(4, "H.jpg"), @img_in) if @option_draw_image

      # 検出箇所に線を引く
      draw_both_run(fn(2, :jpg), fn(4, :jpg), @img_in) if @option_draw_image

      # 検出箇所をCSVファイルに書き出す
      save_coordinate(num: 4, horizontal: true, vertical: true, cross: false) if @option_save_csv

      # 縦方向の線分を統合
      puts "merge_vertical_run" if $DEBUG
      merge_vertical_run

      # 横方向の線分を統合
      puts "merge_horizontal_run" if $DEBUG
      merge_horizontal_run

      # 検出箇所に線を引く
      if @option_draw_image
        draw_vertical_run(fn(2, :jpg), fn(5, "V.jpg"), @img_in)
        draw_horizontal_run(fn(2, :jpg), fn(5, "H.jpg"), @img_in)
        draw_both_run(fn(2, :jpg), fn(5, :jpg), @img_in)
      end

      # 検出箇所をCSVファイルに書き出す
      save_coordinate(num: 5, horizontal: true, vertical: true, cross: false) if @option_save_csv

      # 最初の処理の画像ファイルを削除する
      if !@option_draw_image
        [fn(1, :jpg), fn(2, :pbm), fn(2, :jpg)].each do |filename|
          if test(?f, filename)
            File.unlink(filename)
          end
        end
      end

      # 交差判定
      calc_cross

      # 孤立する短い線分を削除する
      delete_short_line
      # 交差判定をやり直す
      calc_cross

      # 結果をファイルに出力する
      if @option_draw_image
        draw_vertical_run(fn(2, :jpg), fn(6, "V.jpg"), @img_in)
        draw_horizontal_run(fn(2, :jpg), fn(6, "H.jpg"), @img_in)
        draw_both_run(fn(2, :jpg), fn(6, :jpg), @img_in)
      end
      save_coordinate(num: 6, horizontal: true, vertical: true, cross: false) if @option_save_csv

      self
    end

    def f(name)
      @prefix + name
    end

    def mask(param = {})
      img_from = param[:img_from] || @img_in
      img_to = param[:img_to] || fn(1, :jpg)

      # 画像から「XMLファイルのString部分」「@bbox領域外」を削除
      if @reg_a.nil?
        if @xml_in
          pr = Kzd::RegionProcessor.new(@xml_in)
          pr.analyze
          @reg_a = pr.strings
        else
          @reg_a = []
        end
      end

      command = "convert #{img_from}"
      command += " -stroke none -fill white"
      command += " -draw \""
      command += @reg_a.map {|reg|
        rr = reg.box.dup
        "rectangle " + rr.join(",")
      }.join(" ")
      command += "\""

      # 外部を白塗り
      if Array === @bbox
        setup_width_and_height_by_identify
        width = @width_by_identify
        height = @height_by_identify
        if width && height
          command += " -stroke none -fill gray95"
          command += " -draw \""
          command += "rectangle 0,0 #{width},#{@bbox[1] - 1}"
          command += " rectangle 0,#{@bbox[3] + 1} #{width},#{height}"
          command += " rectangle 0,0 #{@bbox[0] - 1},#{height}"
          command += " rectangle #{@bbox[2] + 1},0 #{width},#{height}"
          command += "\""
        end
      end

      command += " -quality 92 #{img_to}"
      puts command if $DEBUG
      system command
    end

    def make_bw_image(param = {})
      # PBM形式の2値モノクロ画像に変換
      img_from = param[:img_from] || @img_in
      img_to = param[:img_to] || fn(2, :pbm)
      param_convert = "-threshold '#{@mono_threshold * 100}%'"

      do_convert(img_from: img_from, img_to: img_to, command: param_convert,
                 quality: false)
    end

    def do_convert(param = {})
      # JPEG形式などに変換
      img_from = param[:img_from] || @img_in
      img_to = param[:img_to] || fn(2, :pbm)
      param_convert = param[:command] || ""
      case param[:quality]
      when false
        param_quality = ""
      when Numeric
        param_quality = "-quality #{param[:quality]}"
      else
        param_quality = "-quality 92"
      end

      command = ["convert", img_from, param_convert, param_quality, img_to].flatten.map {|item| (item.nil? || item.empty?) ? nil : item}.compact.join(" ")
      puts command if $DEBUG
      system command
    end

    def get_pixel(img_in)
      case img_in
      when /pbm$/
        get_pixel_pbm(img_in)
      when /ppm$/
        get_pixel_ppm(img_in)
      else
        raise
      end
    end

    def get_pixel_pbm(img_in)
      # PBM形式より諸情報を獲得
      @img_pixel_in = img_in.dup

      aa = []
      @width = @height = -1

      open(img_in) do |f_in|
        line = f_in.readline.strip
        raise if /^P4$/ !~ line
        puts line if $DEBUG
        line = f_in.readline.strip
        if /(\d+)\s+(\d+)/ =~ line
          @width = $1.to_i
          @height = $2.to_i
        end
        raise "width=#{@width}, height=#{@height}" if @width <= 0 || @height <= 0
        puts [@width, @height].join(" ") if $DEBUG

        a = []
        until (c = f_in.read(1)).nil?
          val = c.ord
          d = 0x80
          8.times do
            a << ((val & d == 0) ? 1 : 0) # 立っているビットは黒
            d >>= 1
          end
          if a.length >= @width
            aa << (a.length > @width ? a[0, @width] : a)
            a = []
          end
        end

        if !a.empty?
          aa << a
          a = []
        end
      end

      if aa.length > @height
        aa = aa[0, @height]
      elsif aa.length < @height
        aa += 1..(@height - aa.length).to_a.map { [0] * @width }
      end

      @pixel_yx = aa  # @pixel_yx[Y座標][X座標]
      @pixel_xy = @pixel_yx.transpose  # @pixel_xy[X座標][Y座標]

      puts "row: #{@pixel_yx.map {|vec| val = vec.sort.index(1); val.nil? ? vec.length : val}.inspect}" if $DEBUG
      puts "col: #{@pixel_xy.map {|vec| val = vec.sort.index(1); val.nil? ? vec.length : val}.inspect}" if $DEBUG
    end

    def get_pixel_ppm(img_in)
      # PPM形式の2値モノクロ画像より諸情報を獲得
      @img_pixel_in = img_in.dup
      open(img_in) do |f_in|
        line = f_in.readline
        raise unless /^P7$/ =~ line

        line = f_in.readline
        if /^WIDTH (\d+)/ =~ line
          @width = $1.to_i
        else
          raise
        end

        line = f_in.readline
        if /^HEIGHT (\d+)/ =~ line
          @height = $1.to_i
        else
          raise
        end

        line = f_in.readline
        raise unless /^DEPTH 1$/ =~ line

        line = f_in.readline
        raise unless /^MAXVAL 1$/ =~ line

        line = f_in.readline
        raise unless /^TUPLTYPE BLACKANDWHITE$/ =~ line

        line = f_in.readline
        raise unless /^ENDHDR$/ =~ line

        @pixel = f_in.read(@width * @height) # 0x00または0x01のバイナリ列
      end

      puts "#{img_in}: #{@width} x #{@height} = #{@width * @height}" if $DEBUG
      puts "pixel: #{@pixel.bytesize} bytes" if $DEBUG

      @pixel_yx = []  # @pixel[Y座標][X座標]
      @height.times do |y|
        @pixel_yx << @pixel[@width * y, @width].unpack("C*")
      end

      @pixel_xy = @pixel_yx.transpose  # @pixel[X座標][Y座標]

      puts "row: #{@pixel_yx.map {|vec| val = vec.sort.index(1); val.nil? ? vec.length : val}.inspect}" if $DEBUG
      puts "col: #{@pixel_xy.map {|vec| val = vec.sort.index(1); val.nil? ? vec.length : val}.inspect}" if $DEBUG
    end

    def detect_vertical_run(img_in)
      # 縦方向に走査
      if img_in != @img_pixel_in
        get_pixel(img_in)
      end

      @va = detect_run(@pixel_xy,  @run_min, @run_out_ratio).map {|a| Kzd::Line.new(ary: a)}
    end

    def draw_vertical_run(img_in, img_out, img_base)
      draw_run(img_in, img_out, @option_draw_on_base ? img_base : img_in, @va)
    end

    def detect_horizontal_run(img_in)
      # 横方向に走査
      if img_in != @img_pixel_in
        get_pixel(img_in)
      end

      @ha = detect_run(@pixel_yx, @run_min, @run_out_ratio, true).map {|a|
        Kzd::Line.new(ary: [a[1], a[0], a[3], a[2]])
      }
    end

    def draw_horizontal_run(img_in, img_out, img_base)
      draw_run(img_in, img_out, @option_draw_on_base ? img_base : img_in, @ha)
    end

    def draw_both_run(img_in, img_out, img_base)
      # @va, @haの値に基づき検出箇所に線を引く
      img_tmp = File.join(File.dirname(img_out), "tmp" + File.basename(img_out))
      draw_run(img_in, img_tmp, @option_draw_on_base ? img_base : img_in, @va)
      draw_run(img_in, img_out, img_tmp, @ha)

      command = "rm #{img_tmp}"
      puts command if $DEBUG
      system command
    end

    def detect_run(pixel_xy, th = 25, ratio = 0.04, flag_transposed = false)
      # pixel_xyを走査して[[x, y1, x, y2], ...]の形式で返す
      # thは直線と判断する閾値
      # ratioは余白カットの割合．ToDo: 削除できないか見直す

      run_a = [] # [[x1, y1, x2, y2], ...]
      pixel_xy.each_with_index do |vec, x|
        y1 = nil
        vec.each_with_index do |v, y|
          if v == 1
            if y1 != nil && y - y1 > th
              run_a << [x, y1, x, y - 1]
              puts "find run: #{run_a.last.inspect} : #{run_a.last[3] - run_a.last[1]} dots" if $DEBUG
            end
            y1 = nil
          else # if v == 1
            if y1 == nil
              y1 = y
            end
          end
        end
        if y1 != nil && vec.length - y1 >= th
          run_a << [x, y1, x, vec.length - 1]
          puts "find run: #{run_a.last.inspect} : #{run_a.last[3] - run_a.last[1]} dots" if $DEBUG
        end
      end
      puts "find #{run_a.length} runs" if $DEBUG
      if Array === @bbox
        if flag_transposed
          ymin, xmin, ymax, xmax = @bbox
        else
          xmin, ymin, xmax, ymax = @bbox
        end
      else
        if flag_transposed
          xmin = @height * ratio
          ymin = @width * ratio
          xmax = @height * (1.0 - ratio)
          ymax = @width * (1.0 - ratio)
        else
          xmin = @width * ratio
          ymin = @height * ratio
          xmax = @width * (1.0 - ratio)
          ymax = @height * (1.0 - ratio)
        end
      end
      run_a.delete_if {|run|
        run[2] < xmin || run[3] < ymin || run[0] > xmax || run[1] > ymax
      }
      puts "find #{run_a.length} runs" if $DEBUG

      run_a
    end

    def draw_run(img_in, img_out, img_base, run_a, strokewidth = 1)
      # ToDo: drawまたはdraw2で呼び出す
      # ToDo: 引数変更(img_inはメソッド内で使用されていない）
      # run_aの値に基づき線を引く
      img_tmp1 = img_out + "_1.jpg"
      img_tmp2 = img_out + "_2.jpg"
      if ENV["TMPDIR"]
        img_tmp1 = File.join(ENV["TMPDIR"], File.basename(img_tmp1))
        img_tmp2 = File.join(ENV["TMPDIR"], File.basename(img_tmp2))
      end
      puts "img_tmp1 = #{img_tmp1}" if $DEBUG
      puts "img_tmp2 = #{img_tmp2}" if $DEBUG

      # img_base => img_tmp1 => img_tmp2 => img_tmp1 => ... => img_tmp1 => img_out
      command = "cp #{img_base} #{img_tmp1}"
      puts command if $DEBUG
      system command

      convert_head = "convert #{img_tmp1} -stroke red -fill none -strokewidth #{strokewidth} -draw \""
      convert_tail = "\" -quality 92 #{img_tmp2}"
      command = ""
      run_a.each_with_index do |run, i|
        if command.empty?
          command = convert_head.dup
        end
        command += "line #{run.to_a.join(',')} "
        if true # 始点と終点に×印
          len = 16
          command += "line #{[run[0] - len, run[1] - len, run[0] + len, run[1] + len].join(',')} "
          command += "line #{[run[0] + len, run[1] - len, run[0] - len, run[1] + len].join(',')} "
          command += "line #{[run[2] - len, run[3] - len, run[2] + len, run[3] + len].join(',')} "
          command += "line #{[run[2] + len, run[3] - len, run[2] - len, run[3] + len].join(',')} "
        end
        if (i + 1) % 100 == 0
          command += convert_tail
          puts command if $DEBUG
          system command
          command = "mv #{img_tmp2} #{img_tmp1}"
          puts command if $DEBUG
          system command
          command = ""
          #        break if i == 999
        end
      end
      if !command.empty?
        command += convert_tail
        puts command if $DEBUG
        system command
        command = "mv #{img_tmp2} #{img_tmp1}"
        puts command if $DEBUG
        system command
        command = ""
      end

      command = "mv #{img_tmp1} #{img_out}"
      puts command if $DEBUG
      system command
    end

    def merge_vertical_run
      # 縦線を結合
      case @merge_margin
      when Array
        th1 = @merge_margin[0]
        th2 = @merge_margin[1]
      when Numeric
        th1 = th2 = @merge_margin
      else
        th2 = @height * @merge_vertical_ratio
        th1 = th2 * 0.5
      end
      @va = merge_run(@va, th1, th2).map {|run| Kzd::Line.new(ary: run)}
    end

    def merge_horizontal_run
      # 横線を結合
      case @merge_margin
      when Array
        th1 = @merge_margin[1]
        th2 = @merge_margin[0]
      when Numeric
        th1 = th2 = @merge_margin
      else
        th2 = @width * @merge_horizontal_ratio
        th1 = th2 * 0.5
      end
      a1 = @ha.map {|run|
        Kzd::Line.new(ary: [run[1], run[0], run[3], run[2]])
      }
      a2 = merge_run(a1, th1, th2)
      @ha = a2.map {|run|
        Kzd::Line.new(ary: [run[1], run[0], run[3], run[2]])
      }
    end

    def merge_run(run_a, th1, th2)
      # 走査を結合して[[x, y1, x, y2], ...]の形式で返す
      # run_a = [Kzd:Line instance, ...]
      "merge_run: th1=#{th1} th2=#{th2}" if $DEBUG

      a1 = run_a.sort_by {|run|
        (run[2] - run[0]) ** 2 + (run[3] - run[1]) ** 2
      }.map {|run|
        [[run[0], run[2]].min,
          [run[1], run[3]].min,
          [run[0], run[2]].max,
          [run[1], run[3]].max,
          1]
      } # [[x_min, y_min, x_max, y_max, freq], ...]
      a2 = [] # [[x_min, y_min, x_max, y_max, freq], ...]

      loop_count = 0
      while a1.size != a2.size # true
        puts " debug: loop_count #{loop_count += 1}" if $DEBUG
        a1.each do |run1|
          no_match = true
          a2.each_with_index do |run2, i|
            range1x = Range.new(run1[0] - th1, run1[2] + th1)
            range2x = Range.new(run2[0] - th1, run2[2] + th1)
            range1y = Range.new(run1[1] - th2, run1[3] + th2)
            range2y = Range.new(run2[1] - th2, run2[3] + th2)
            if (range2x.include?(range1x.min) || range2x.include?(range1x.max) ||
                range1x.include?(range2x.min) || range1x.include?(range2x.max)) &&
                (range2y.include?(range1y.min) || range2y.include?(range1y.max) ||
                range1y.include?(range2y.min) || range1y.include?(range2y.max))
              x_min = [run1[0], run2[0]].min
              y_min = [run1[1], run2[1]].min
              x_max = [run1[2], run2[2]].max
              y_max = [run1[3], run2[3]].max
              count = run1[4] + run2[4]
              a2[i] = [x_min, y_min, x_max, y_max, count]
              # puts "debug: replace(i), #{a2.last.inspect}" if $DEBUG
              no_match = false
              break
            end
          end
          if no_match
            a2 << run1
            # puts "debug: add #{a2.last.inspect}" if $DEBUG
          end
        end

        a2.sort {|x, y|
          (x[0] != y[0]) ? (x[0] - y[0]) :
          ((x[1] != y[1]) ? (x[1] - y[1]) : (x[3] - y[3]))
        }.each_with_index do |run, i|
          puts "  No.#{i + 1} : (#{run[0]},#{run[1]})-(#{run[2]},#{run[3]}), #{run[4]} time(s)" if $DEBUG
        end

        break if a1.size == a2.size
        a1 = a2
        a2 = []
      end

      a3 = a2.map {|run|
        x = (run[0] + run[2]) / 2
        [x, run[1], x, run[3]]
      }

      a3
    end

    def save_run(ary, filename)
      # [[x1, y1, x2, y2], ...]の値をファイルに書き出す
      puts "save_run(#{filename})" if $DEBUG

      open(filename, "w") do |f_out|
        ary.sort {|x, y|
          (x[0] != y[0]) ? (x[0] - y[0]) :
          ((x[1] != y[1]) ? (x[1] - y[1]) : (x[3] - y[3]))
        }.each_with_index do |run, i|
          line = run.to_a.join(",") + "\r\n"
          f_out.print line
          print line if $DEBUG
        end
      end
    end

    def save_coordinate(param = {})
      # 横線・縦線・交点の座標をCSVファイルに保存する
      num = param[:num] || param[:dir]

      if param[:v] || param[:vertical]
        save_run(@va, fn(num, "V.csv"))
      end

      if param[:h] || param[:horizontal]
        save_run(@ha, fn(num, "H.csv"))
      end

      if param[:x] || param[:cross]
        open(fn(num, "X.csv"), "w") do |f_out|
          @xaa.each do |a|
            b = a[2] + @va[a[0]].to_a + @ha[a[1]].to_a
            f_out.print b.join(",") + "\r\n"
          end
        end
      end

      self
    end

    def load_coordinate(param = {})
      # 横線・縦線・交点の座標を記したCSVファイルを読み出す
      num = param[:num] || param[:dir]

      if param[:v] || param[:vertical]
        @va = open(fn(num, "V.csv")).read.strip.split(/\n+/).map {|line| Kzd::Line.new(ary: line.split(/,/).map {|v| v.to_i})}
      end

      if param[:h] || param[:horizontal]
        @ha = open(fn(num, "H.csv")).read.strip.split(/\n+/).map {|line| Kzd::Line.new(ary: line.split(/,/).map {|v| v.to_i})}
      end

      if param[:x] || param[:cross]
        @xaa = []
        va4 = @va.map {|item| item.to_a}
        ha4 = @ha.map {|item| item.to_a}
        # run_h_a.index(line_a[5, 4])
        open(fn(num, "X.csv")) do |f_out|
          f_out.each_line do |line|
            next if /^\s*\#/ =~ line
            line_a = line.strip.split(/,/)
            if line_a.length != 10
              puts "skipped: #{line.strip}" if $DEBUG
              next
            end
            pos_v = va4.index(line_a[0, 4])
            pos_h = ha4.index(line_a[5, 4])
            if pos_v && pos_h
              @xaa << [pos_v, pos_h, line_a[9, 2]]
            else
              puts "skipped (line not found): #{line.strip}" if $DEBUG
            end
          end
        end
      end

      self
    end

    def lines(opt = nil)
      # @va, @haの値をKzd::Lineインスタンスの配列として返す
      case opt
      when :h, :horizontal, :yoko
        return @ha
      when :v, :vertical, :tate
        return @va
      end
      @ha + @va
    end

    def horizontal_lines
      lines(:h)
    end

    def vertical_lines
      lines(:v)
    end

    # 古いデータ構造による縦線・横線の扱い
    def run_v_a
      @va.map {|line| line.to_a}
    end

    def run_v_a=(a)
      @va = a.map {|item| Kzd::Line.new(ary: item)}
    end

    def run_h_a
      @ha.map {|line| line.to_a}
    end

    def run_h_a=(a)
      @ha = a.map {|item| Kzd::Line.new(ary: item)}
    end

    def calc_cross
      # 交差判定
      @xaa = [] # [[縦線の添字, 横線の添字, [交点x, 交点y]], ...]

      ha2 = @ha.map {|item| Kzd::Line.new(ary: item.to_a, tolerance: @cross_tolerance) }
      va2 = @va.map {|item| Kzd::Line.new(ary: item.to_a, tolerance: @cross_tolerance) }
      va2.each_with_index do |vi, i|
        ha2.each_with_index do |hj, j|
          a = vi.cross(hj)
          if a
            @xaa << [i, j, a]
          end
        end
      end

      # CSVファイルに保存する
      save_coordinate(cross: true) if @option_save_csv

      self
    end

    def find_intersection(param)
      # 引数となる線分（[x1, y1, x2, y2]またはKzd::Lineインスタンス）と
      # 交差する線分を求め，@xaaの部分リスト（配列の配列）を返す．
      # ない場合はnilを返す．
      case param
      when Kzd::Line
        line = param
        a = param.to_a
      when Array
        line = Kzd::Line.new(ary: a)
        a = param
      else
        raise
      end

      if line.vertical?
        # 縦線のとき
        pos = nil
        @va.each_with_index do |line2, i|
          if line.to_a == line2.to_a
            pos = i
            break
          end
        end
        # pos = @run_v_a.index(a)
        return nil if pos.nil?

        b = []
        @xaa.each do |a2|
          if a2[0] == pos
            b << a2
          end
        end
      else
        # 横線のとき
        pos = nil
        @ha.each_with_index do |line2, i|
          if line.to_a == line2.to_a
            pos = i
            break
          end
        end
        # pos = @run_h_a.index(a)
        return nil if pos.nil?

        b = []
        @xaa.each do |a2|
          if a2[1] == pos
            b << a2
          end
        end
      end

      b.empty? ? nil : b
    end
    alias :find_cross :find_intersection

    def find_name_and_vline(tole = 40)
      # 人物情報の文字列と，それにつながる縦線の組を，
      # [Kzd::Region instance, Kzd::Line instance, :topまたは:bot, [x, y]]
      # の配列で返す．ない場合には空配列を返す．
      result_a = []
      vertical_lines.each do |line|
        [:top, :bot].each do |pos|
          reg_closest = nil
          distance = -1
          tole_sq = tole * tole
          x1 = line.x1
          y1 = (pos == :top) ? line.y2 : line.y1
          @reg_a.each do |reg|
            next if /\d|「|」|『|』/ =~ reg.string
            x2 = reg.center
            y2 = (pos == :top) ? reg.top : reg.bottom
            next if (x1 - x2).abs > tole / 2 || (y1 - y2).abs > tole
            d = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
            next if d > tole_sq
            if reg_closest.nil? || d < distance
              reg_closest = reg
              distance = d
            end
          end
          if reg_closest
            result_a << [reg_closest.dup, line.dup, pos, [x1, y1]]
          end
        end
      end
      result_a
    end

    def find_outside_hline(tole = 20, limit = 0.1)
      # 隣接ページとまたがる横線を
      # [Kzd::Line instance, :leftまたは:rightまたは:both]
      # の配列で返す．ない場合には空配列を返す．
      # @xaa # [[縦線の添字, 横線の添字, [交点x, 交点y]], ...]
      setup_bbox
      image_x_min, image_x_max = @bbox[0], @bbox[2]
      threshold_left = (@bbox[0] * (1.0 - limit) + @bbox[2] * limit).to_i
      threshold_right = (@bbox[0] * limit + @bbox[2] * (1.0 - limit)).to_i

      result_a = []
      horizontal_lines.each_with_index do |line, i|
        sym = :none # :none, :left, :right, :both
        cross_x_a = @xaa.map {|item| item[1] == i ? item[2][0] : nil}.compact
        # 左端判定：横線の始点が左10%以内にあり，cross_x_aが空か，cross_x_a.min - 始点がtole以上
        if line.x1 <= threshold_left &&
            (cross_x_a.empty? || cross_x_a.min - line.x1 >= tole)
          sym = :left
        end
        # 右端判定：横線の終点が右10%以内にあり，cross_x_aが空か，終点 - cross_x_a.maxがtole以上
        if line.x2 >= threshold_right &&
            (cross_x_a.empty? || line.x2 - cross_x_a.max >= tole)
          sym = (sym == :left) ? :both : :right
        end
        if sym != :none
          result_a << [line.dup, sym]
        end
      end

      result_a
    end

    def delete_short_line(th = nil)
      # 孤立する短い線分を削除する
      # @xaa, @va, @haを参照し，@va, @haを必要に応じて変更する（要素数を減らす）
      # @xaaは変更しない（別途calc_crossを呼び出す必要がある）
      if !(Numeric === th)
        if Array === @reg_a && !@reg_a.empty?
          th = @reg_a.map {|reg| reg.width}.inject(:+).to_f / @reg_a.length # 全領域の幅の平均値
        else
          th = 20
        end
      end

      del_v_a = [] # @vaにおける削除対象の添字の配列
      cross_v_a = @xaa.map {|item| item[0]}.sort.uniq
      @va.each_with_index do |run_v, i|
        next if cross_v_a.include?(i)
        next if run_v[3] - run_v[1] >= th
        del_v_a << i
      end

      del_h_a = [] # @haにおける削除対象の添字の配列
      cross_h_a = @xaa.map {|item| item[1]}.sort.uniq
      @ha.each_with_index do |run_h, i|
        next if cross_h_a.include?(i)
        next if run_h[2] - run_h[0] >= th
        del_h_a << i
      end

      # @vaおよび@haから削除
      del_v_a.reverse.each do |i|
        a = @va[i]
        puts "delete vertical line (#{a[0]},#{a[1]})-(#{a[2]},#{a[3]})" if $DEBUG
        @va.delete_at(i)
      end
      del_h_a.reverse.each do |i|
        a = @ha[i]
        puts "delete vertical line (#{a[0]},#{a[1]})-(#{a[2]},#{a[3]})" if $DEBUG
        @ha.delete_at(i)
      end

      self
    end

    def draw(param)
      # param（Hashの配列）の内容に応じて画像上に線や記号を書き入れる
      img_from = @img_in # 元画像
      img_to = fn("_draw.jpg") # 最終画像
      img_tmp1 = nil # 非nilのとき，その名前で画像が（一時的に）作られる
      img_tmp2 = nil # 非nilのとき，その名前で画像が（一時的に）作られる
      # img_from => img_tmp2 => img_tmp1 => img_tmp2 => ... => img_tmp2 => img_to

      param.each do |h1|
        raise unless Hash === h1
        if h1.key?(:img_from)
          # 元画像の指定
          img_from = h1[:img_from]
        end

        if h1.key?(:img_to)
          # 最終画像の指定
          img_to = h1[:img_to]
        end

        case h1[:type]
          # 画像上に線や記号を乗せる
        when :line, :circle, :endpoint, :rectangle
          h2 = h1.dup
          if img_tmp1.nil?
            img_tmp1 = img_from
          end
          h2[:img_from] = img_tmp1
          img_tmp2 = fn("tmp2.jpg")
          if ENV["TMPDIR"]
            img_tmp2 = File.join(ENV["TMPDIR"], File.basename(img_tmp2))
          end
          h2[:img_to] = img_tmp2 = fn("tmp2.jpg")

          add_convert_params(h2)
          send("add_draw_#{h1[:type]}", h2)
          command = [:convert_start, :shape, :draw_start, :draw_param, :draw_end, :convert_end].map {|key| h2[key] || ""}.join(" ")
          puts command if $DEBUG
          system command

          img_tmp1 = fn("tmp1.jpg")
          if ENV["TMPDIR"]
            img_tmp1 = File.join(ENV["TMPDIR"], File.basename(img_tmp1))
          end
          FileUtils.mv(img_tmp2, img_tmp1)
          img_tmp2 = nil
        end
      end

      if img_tmp1
        FileUtils.mv(img_tmp1, img_to)
        img_tmp1 = nil
      end

      self
    end

    def draw2(param2)
      # param2（Hash）の内容に応じて画像上に線や記号を書き入れる
      img_from = param2[:img_from] || @img_in # 元画像
      img_to = param2[:img_to] || fn("_draw.jpg") # 最終画像
      pr = param2[:reg]
      if !pr.nil?
        r_a = pr.strings
      else
        r_a = @reg_a || []
      end

      param = [{:img_from => img_from, :img_to => img_to}]

      case param2[:obj]
      when Array
        # do nothing
      when nil
        param2[:obj] = []
      else
        param2[:obj] = [param2[:obj]]
      end

      if param2[:all]
        [:bbox, :vline, :vend, :hline, :cross, :hend, :person, :comment, :corr].each do |sym|
          param2[sym] = true
        end
      end

      if (param2[:bbox] || param2[:obj].include?(:bbox)) && Array === @bbox
        param << {:type => :rectangle, :value => [@bbox], :stroke => "gray50", :strokewidth => 3, :fill => "none", :margin => 0}
      end
      if param2[:vline] || param2[:obj].include?(:vline)
        param << {:type => :line, :value => @va, :stroke => "blue", :strokewidth => 6}
      end
      if param2[:vend] || param2[:obj].include?(:vend)
        param << {:type => :endpoint, :value => @va, :stroke => "blue", :strokewidth => 6, :size => 40}
      end
      if param2[:hline] || param2[:obj].include?(:hline)
        param << {:type => :line, :value => @ha, :stroke => "red", :strokewidth => 6}
      end
      if param2[:hend] || param2[:obj].include?(:hend)
        param << {:type => :endpoint, :value => @ha, :stroke => "red", :strokewidth => 6, :size => 40}
      end
      if param2[:cross] || param2[:obj].include?(:cross)
        param << {:type => :circle, :value => @xaa.map {|item| item.last}, :stroke => "green", :strokewidth => 6, :fill => "none", :radius => 12}
      end
      if param2[:comment] || param2[:obj].include?(:comment)
        param << {:type => :rectangle, :value => r_a.map {|item| item.comment? ? item.box : nil}.compact, :stroke => "darkgreen", :strokewidth => 3, :fill => "none"}
      end
      if param2[:person] || param2[:obj].include?(:person)
        param << {:type => :rectangle, :value => r_a.map {|item| item.person? ? item.box : nil}.compact, :stroke => "purple", :strokewidth => 3, :fill => "none"}
      end
      if (param2[:corr] || param2[:obj].include?(:corr)) && pr
        corr_a = pr.cpidx.keys.map {|idx| r_a[idx].heart + r_a[pr.cpidx[idx]].heart }
        param << {:type => :line, :value => corr_a, :stroke => "cyan", :strokewidth => 3}
      end

      draw(param)
    end

    def add_convert_params(h)
      h[:convert_start] = "convert \"#{h[:img_from]}\""
      h[:convert_end] = " -quality 92 \"#{h[:img_to]}\""
      h[:draw_start] = " -draw \""
      h[:draw_end] = "\""
      shape = ""
      [:stroke, :strokewidth, :fill, :color].each do |sym|
        if h.key?(sym)
          shape += " -#{sym} \"#{h[sym]}\""
        end
      end
      h[:shape] = shape

      h
    end

    def add_draw_line(h)
      h[:draw_param] = h[:value].map {|a| "line " + a.to_a[0, 4].join(",")}
      h
    end

    def add_draw_circle(h)
      radius = (h[:radius] || 4).to_i
      h[:draw_param] = h[:value].map {|a| "circle #{a[0]},#{a[1]},#{a[0] + radius},#{a[1]}"}
      h
    end

    def add_draw_endpoint(h)
      s = (h[:size] || 6) * 0.5
      s = s.to_i if s.to_f == s.to_i
      h[:draw_param] = h[:value].map {|a|
        "line #{a[0] - s},#{a[1] - s},#{a[0] + s},#{a[1] + s}" +
        " line #{a[0] - s},#{a[1] + s},#{a[0] + s},#{a[1] - s}" +
        " line #{a[2] - s},#{a[3] - s},#{a[2] + s},#{a[3] + s}" +
        " line #{a[2] - s},#{a[3] + s},#{a[2] + s},#{a[3] - s}"
      }
      h
    end

    def add_draw_rectangle(h)
      margin = (h[:margin] || 0).to_i
      h[:draw_param] = h[:value].map {|a| "rectangle " + [a[0] - margin, a[1] - margin, a[2] + margin, a[3] + margin].join(",")}
      # h[:draw_param] = h[:value].map {|a| "rectangle " + a[0, 4].join(",")}
      h
    end

    def setup_width_and_height_by_identify
      # identifyコマンドを実行して，画像の幅と高さを求める
      return [@width_by_identify, @height_by_identify] if @width_by_identify && @height_by_identify
      return [9999, 9999] unless test(?f, @img_in)
      identify_result = `identify #{@img_in}`
      if / (\d+)x(\d+) / =~ identify_result
        @width_by_identify, @height_by_identify = $1.to_i, $2.to_i
      end
      [@width_by_identify, @height_by_identify]
    end

    def setup_bbox
      # @run_out_ratioに基づき，画像処理領域を設定する
      return @bbox if @bbox

      setup_width_and_height_by_identify
      width = @width_by_identify
      height = @height_by_identify
      if width && height
        xmin = width * @run_out_ratio
        ymin = height * @run_out_ratio
        xmax = width * (1.0 - @run_out_ratio)
        ymax = height * (1.0 - @run_out_ratio)
        @bbox = [xmin, ymin, xmax, ymax]
      end
    end
  end
end
