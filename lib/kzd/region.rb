module Kzd
  class Region
    def initialize(opt = {})
      @x = (opt[:hpos] || opt[:x] || 0).to_i
      @y = (opt[:vpos] || opt[:y] || 0).to_i
      @width = (opt[:width] || 0).to_i
      @height = (opt[:height] || 0).to_i
      @string = opt[:string] || ""
      @type = opt[:type] # :person, :comment, nil
    end
    attr_accessor :x, :y, :width, :height, :string, :type
    alias_method :hpos=, :x=
    alias_method :hpos, :x
    alias_method :vpos=, :y=
    alias_method :vpos, :y

    # option_descreteが真のとき，返す座標は整数値とし，
    # 右のX座標や下のY座標については1減らす

    def left(option_descrete = true)
      option_descrete ? @x.to_i : @x
    end

    def top(option_descrete = true)
      option_descrete ? @y.to_i : @y
    end

    def center(option_descrete = true)
      p = @x + @width * 0.5
      p = p.to_i if option_descrete || p.to_i.to_f == p
      p
    end

    def right(option_descrete = true)
      x = @x + @width - (option_descrete ? 1 : 0)
      option_descrete ? x.to_i : x
    end

    def bottom(option_descrete = true)
      y = @y + @height - (option_descrete ? 1 : 0)
      option_descrete ? y.to_i : y
    end
    alias_method :bot, :bottom

    def middle(option_descrete = true)
      p = @y + @height * 0.5
      p = p.to_i if option_descrete || p.to_i.to_f == p
      p
    end

    def to_s(option_descrete = true)
      "(%d,%d)-(%d,%d)%s" % [left, top,
        right(option_descrete), bottom(option_descrete),
        string.empty? ? "" : ": " + string]
    end

    def box(opt = {})
      option_descrete = !(opt[:descrete] == false)
      p1 = left(option_descrete)
      p2 = top(option_descrete)
      p3 = right(option_descrete)
      p4 = bottom(option_descrete)

      if opt[:strokewidth]
        sw = ((Numeric === opt[:strokewidth]) ? opt[:strokewidth] : 1).to_f
        swh = sw / 2
        p1 -= swh
        p2 -= swh
        p3 += swh
        p4 += swh
      end

      [p1, p2, p3, p4]
    end

    def box_sw(sw)
      box(:strokewidth => sw)
    end

    def centertop(option_descrete = true)
      [center(option_descrete), top]
    end

    def centerbottom(option_descrete = true)
      [center(option_descrete), bottom(option_descrete)]
    end
    alias :centerbot :centerbottom

    def leftmiddle(option_descrete = true)
      [left, middle(option_descrete)]
    end

    def rightmiddle(option_descrete = true)
      [right(option_descrete), middle(option_descrete)]
    end

    def heart(option_descrete = true)
      [center(option_descrete), (top + bottom(option_descrete)) * 0.5]
    end

    def person?
      @type == :person
    end
    alias :person_name? :person?

    def comment?
      @type == :comment
    end

    def unidentified?
      @type.nil?
    end

    def set_person
      @type = :person
      self
    end
    alias :set_person_name :set_person

    def set_comment
      @type = :comment
      self
    end

    def set_unidentified
      @type = nil
      self
    end
  end
end
