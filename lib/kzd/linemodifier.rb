module Kzd
  module LineModifier
    def modify(op_a)
      op_a.each do |op_h|
        op_h.each_pair do |op, geo|
          bbox = lmff_geo_to_bbox(geo)
          next if !(Array === bbox)

          case op.to_sym
          when :add_v
            x = ((bbox[0] + bbox[2]) / 2).to_i
            @va << Kzd::Line.new(ary: [x, bbox[1], x, bbox[3]])
            puts "    #{op}(#{geo}) inserts 1 line." if $DEBUG
          when :del_v
            v_a = @va.map {|a| lmff_include?(bbox, a.to_a) ? a : nil}.compact
            @va -= v_a
            puts "    #{op}(#{geo}) deletes #{v_a.length} line(s)." if $DEBUG
          when :merge_v
            v_a = @va.map {|a| lmff_include?(bbox, a) ? a : nil}.compact
            if !v_a.empty?
              y1 = v_a.map {|a| a[1]}.min
              y2 = v_a.map {|a| a[3]}.max
              a2 = v_a.map {|a| [a[0], a[3] - a[1]]}
              x = (a2.map {|a| a[0] * a[1]}.inject(:+) / a2.map {|a| a[1]}.inject(:+)).to_i # 重み付き平均
              new_line = [x, y1, x, y2]
              @va -= v_a
              @va << Kzd::Line.new(ary: new_line)
              puts "    #{op}(#{geo}) deletes #{v_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts 1 line." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :expand_up
            v_a = @va.map {|a| lmff_include?(bbox, a) ? a : nil}.compact
            v_a2 = v_a.map {|a| Kzd::Line.new(ary: [a[0], bbox[1], a[2], a[3]])}
            if !v_a.empty?
              @va -= v_a
              @va += v_a2
              puts "    #{op}(#{geo}) deletes #{v_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{v_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :expand_down
            v_a = @va.map {|a| lmff_include?(bbox, a.to_a) ? a : nil}.compact
            v_a2 = v_a.map {|a| Kzd::Line.new(ary: [a[0], a[1], a[2], bbox[3]])}
            if !v_a.empty?
              @va -= v_a
              @va += v_a2
              puts "    #{op}(#{geo}) deletes #{v_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{v_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :shrink_up
            v_a = @va.map {|a| lmff_include_point?(bbox, a.to_a[2..3]) ? a : nil}.compact
            v_a2 = v_a.map {|a| Kzd::Line.new(ary: [a[0], bbox[1], a[2], a[3]])}
            if !v_a.empty?
              @va -= v_a
              @va += v_a2
              puts "    #{op}(#{geo}) deletes #{v_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{v_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :shrink_down
            v_a = @va.map {|a| lmff_include_point?(bbox, a.to_a[0..1]) ? a : nil}.compact
            v_a2 = v_a.map {|a| Kzd::Line.new(ary: [a[0], a[1], a[2], bbox[3]])}
            if !v_a.empty?
              @va -= v_a
              @va += v_a2
              puts "    #{op}(#{geo}) deletes #{v_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{v_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :add_h
            y = ((bbox[1] + bbox[3]) / 2).to_i
            @ha << Kzd::Line.new(ary: [bbox[0], y, bbox[2], y])
            puts "    #{op}(#{geo}) inserts 1 line." if $DEBUG
          when :del_h
            h_a = @ha.map {|a| lmff_include?(bbox, a) ? a : nil}.compact
            @ha -= h_a
            puts "    #{op}(#{geo}) deletes #{h_a.length} line(s)." if $DEBUG
          when :merge_h
            h_a = @ha.map {|a| lmff_include?(bbox, a) ? a : nil}.compact
            if !h_a.empty?
              x1 = h_a.map {|a| a[0]}.min
              x2 = h_a.map {|a| a[2]}.max
              a2 = h_a.map {|a| [a[1], a[2] - a[0]]}
              y = (a2.map {|a| a[0] * a[1]}.inject(:+) / a2.map {|a| a[1]}.inject(:+)).to_i # 重み付き平均
              new_line = [x1, y, x2, y]
              @ha -= h_a
              @ha << Kzd::Line.new(ary: new_line)
              puts "    #{op}(#{geo}) deletes #{h_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts 1 line." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :expand_left
            h_a = @ha.map {|a| lmff_include?(bbox, a) ? a : nil}.compact
            h_a2 = h_a.map {|a| Kzd::Line.new(ary: [bbox[0], a[1], a[2], a[3]])}
            if !h_a.empty?
              @ha -= h_a
              @ha += h_a2
              puts "    #{op}(#{geo}) deletes #{h_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{h_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change."
            end
          when :expand_right
            h_a = @ha.map {|a| lmff_include?(bbox, a) ? a : nil}.compact
            h_a2 = h_a.map {|a| Kzd::Line.new(ary: [a[0], a[1], bbox[2], a[3]])}
            if !h_a.empty?
              @ha -= h_a
              @ha += h_a2
              puts "    #{op}(#{geo}) deletes #{h_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{h_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :shrink_left
            h_a = @ha.map {|a| lmff_include_point?(bbox, a.to_a[2..3]) ? a : nil}.compact
            h_a2 = h_a.map {|a| Kzd::Line.new(ary: [bbox[0], a[1], a[2], a[3]])}
            if !h_a.empty?
              @ha -= h_a
              @ha += h_a2
              puts "    #{op}(#{geo}) deletes #{h_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{h_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :shrink_right
            h_a = @ha.map {|a| lmff_include_point?(bbox, a.to_a[0..1]) ? a : nil}.compact
            h_a2 = h_a.map {|a| Kzd::Line.new(ary: [a[0], a[1], bbox[2], a[3]])}
            if !h_a.empty?
              @ha -= h_a
              @ha += h_a2
              puts "    #{op}(#{geo}) deletes #{h_a.length} line(s)." if $DEBUG
              puts "    #{op}(#{geo}) inserts #{h_a.length} line(s)." if $DEBUG
            else
              puts "    #{op}(#{geo}) does not change." if $DEBUG
            end
          when :nop
            puts "    #{op}(#{geo}) does not change." if $DEBUG
          else
            # do nothing
          end
        end
      end
    end

    def remove_cross(op_a)
      op_a.each do |op_h|
        op_h.each_pair do |op, geo|
          next if op != "no_cross"
          bbox = lmff_geo_to_bbox(geo)
          next if !(Array === bbox)
          p_a = @xaa.map {|a| lmff_include_point?(bbox, a[2]) ? a : nil}.compact
          @xaa -= p_a
          puts "    #{op}(#{geo}) deletes #{p_a.length} intersection(s)."
        end
      end
    end

    def lmff_geo_to_bbox(geo)
      if /(\d+)x(\d+)\+(\d+)\+(\d+)/ =~ geo
        w, h, x0, y0 = $1.to_i, $2.to_i, $3.to_i, $4.to_i
        xmin = x0
        ymin = y0
        xmax = x0 + w
        ymax = y0 + h
        bbox = [xmin, ymin, xmax, ymax]
        # bbox_s = "(#{bbox[0]},#{bbox[1]})-(#{bbox[2]},#{bbox[3]})"
      else
        return nil
      end
      bbox
    end

    def lmff_include?(bbox, line)
      if rand(100) == 0 && false
        puts "<DEBUG> lmff_include?([#{bbox.join(',')}], [#{line.join(',')}])"
      end

      bbox[0] <= line[0] && line[0] <= bbox[2] &&
        bbox[0] <= line[2] && line[2] <= bbox[2] &&
        bbox[1] <= line[1] && line[1] <= bbox[3] &&
        bbox[1] <= line[3] && line[3] <= bbox[3]
    end

    def lmff_include_point?(bbox, point)
      bbox[0] <= point[0] && point[0] <= bbox[2] &&
        bbox[1] <= point[1] && point[1] <= bbox[3]
    end

    def draw_by_modifier(op_a, img_from = nil, img_to = nil)
      img_from ||= fn("7.jpg")
      img_to ||= fn("8.jpg")
      command = "convert \"#{img_from}\""
      command += " -stroke gray25 -fill none -strokewidth 5"
      command += " -draw \""
      op_a.each do |op_h|
        op_h.each_pair do |op, geo|
          bbox = lmff_geo_to_bbox(geo)
          if bbox
            command += " rectangle " + bbox.join(",")
          end
        end
      end
      command += "\""
      command += " -quality 92 #{img_to}"
      puts "#{img_from} => #{img_to}"
      puts command
      system command
    end
  end
end
