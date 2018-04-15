module Kzd
  class Line
    def initialize(opt = {})
      @x1 = (opt[:x1] || 0).to_i
      @x2 = (opt[:x2] || 0).to_i
      @y1 = (opt[:y1] || 0).to_i
      @y2 = (opt[:y2] || 0).to_i
      @tolerance = (opt[:tolerance] || 10).to_i
      if Array === opt[:ary] || Kzd::Line == opt[:ary]
        @x1, @y1, @x2, @y2 = opt[:ary][0, 4]
      end
      normalize
    end
    attr_accessor :x1, :x2, :y1, :y2

    def normalize
      if @x1 > @x2
        @x1, @x2 = @x2, @x1
      end
      if @y1 > @y2
        @y1, @y2 = @y2, @y1
      end
      self
    end

    def to_a
      [@x1, @y1, @x2, @y2]
    end

    def to_s
      "(#{@x1},#{@y1})-(#{@x2},#{@y2})"
    end

    def [](nth)
      raise if !(Numeric === nth) || nth < 0 || nth > 3
      to_a[nth]
    end

    def []=(nth, val)
      case nth
      when 0
        @x1 = val
      when 1
        @y1 = val
      when 2
        @x2 = val
      when 3
        @y2 = val
      else
        raise
      end
    end

    def first
      to_a.first
    end

    def last
      to_a.last
    end

    def vertical?
      @x1 == @x2 && @y1 != @y2
    end
    alias :tate? :vertical?

    def horizontal?
      @y1 == @y2 && @x1 != @x2
    end
    alias :yoko? :horizontal?

    def intersect(line2)
      # 交差していれば交点[x, y]を，そうでなければnilを返す

      if (vertical? && line2.vertical?) || (horizontal? && line2.horizontal?)
        return overlap(line2)
      end

      a1 = to_a
      if horizontal?
        a1[0] -= @tolerance
        a1[2] += @tolerance
      elsif vertical?
        a1[1] -= @tolerance
        a1[3] += @tolerance
      end
      a2 = line2.to_a
      if line2.horizontal?
        a2[0] -= @tolerance
        a2[2] += @tolerance
      elsif line2.vertical?
        a2[1] -= @tolerance
        a2[3] += @tolerance
      end
      if vertical?
        transposed = true
        a1 = [a1[1], a1[0], a1[3], a1[2]]
        a2 = [a2[1], a2[0], a2[3], a2[2]]
      else
        transposed = false
      end

      if a1[0] <= a2[0] && a2[0] <= a1[2] &&
          a2[1] <= a1[1] && a1[1] <= a2[3]
        a3 = [a2[0], a1[1]]
        if transposed
          a3 = [a3[1], a3[0]]
        end
        return a3
      end

      nil
    end
    alias :cross :intersect
    alias :intersection :intersect

    def overlap(line2)
      # 交差していれば交点[x, y]を，そうでなければnilを返す
      # （同じ向きの2線分の交差判定）

      if !((vertical? && line2.vertical?) || (horizontal? && line2.horizontal?))
        return nil
      end
      a1 = to_a
      a2 = line2.to_a
      if vertical?
        transposed = true
        a1 = [a1[1], a1[0], a1[3], a1[2]]
        a2 = [a2[1], a2[0], a2[3], a2[2]]
      else
        transposed = false
      end
      if a1.first > a2.first
        a1, a2 = a2, a1
      end

      if a1[0] <= a2[0] && a2[0] <= a1[2]
        if (a1[1] - a2[1]).abs <= @tolerance
          x = (a1[0] + [a1[2], a2[2]].max) / 2
          y = (a1[1] + a2[1]) / 2
          a3 = [x, y]
          if transposed
            a3 = [a3[1], a3[0]]
          end
          return a3
        end
      elsif (a2[0] - a1[2]) ** 2 + (a1[1] - a2[1]) ** 2 <= @tolerance ** 2
        x = (a2[0] + a1[2]) / 2
        y = (a1[1] + a2[1]) / 2
        a3 = [x, y]
        if transposed
          a3 = [a3[1], a3[0]]
        end
        return a3
      end

      nil
    end
    alias :intersection_same_vector :overlap
  end
end
