#!/usr/bin/env ruby

require "test/unit"
require_relative "../lib/kzd.rb"

class TestRoot < Test::Unit::TestCase
  def test_pages
    # ページ管理（複数ページ）のテスト
    man = Kzd::Manager.new
    p1 = Kzd::Page.new(key: "サンプル系図_13",
                       img: "img/サンプル系図_13.jpg",
                       xml: "xml/サンプル系図_13.xml")
    man.add_page(p1)
    p2 = Kzd::Page.new(key: "サンプル系図_14",
                       img: "img/サンプル系図_14.jpg",
                       xml: "xml/サンプル系図_14.xml")
    man.add_page(p2)

    # ページ数
    assert_equal(2, man.pages.length)

    # ページ名
    assert_equal("サンプル系図_13", man.page_to_key(p1))
    assert_equal(p2.key, man.page_to_key(p2))

    # 前後のページ
    assert_equal(p2, man.next_page(p1))
    assert_nil(man.next_page(p2))
    assert_equal(p1, man.prev_page(p2))
    assert_nil(man.prev_page(p1))
    assert_raises { man.next_page("サンプル系図_15") }
    assert_raises { man.prev_page("サンプル系図") }
  end

  def test_region
    # 文字列領域に関するテスト
    r1 = Kzd::Region.new(hpos: 100, vpos: 120, width: 10, height: 20,
                         string: "R1", type: :person)

    # 以下の引数にfalseを書いている箇所は，領域を連続量とみなす．
    # そうでない箇所は，ピクセル画像内の領域とみなしており，
    # 座標はすべて整数値とし，下端と右端は1小さくなっている．
    assert_equal([100, 120, 109, 139], r1.box)
    assert_equal([100, 120, 110, 140], r1.box(descrete: false))
    assert_equal([99, 119, 110, 140], r1.box(strokewidth: 2))
    assert_equal([99, 119, 111, 141], r1.box(descrete: false, strokewidth: 2))
    assert_equal([105, 120], r1.centertop)
    assert_equal([105, 139], r1.centerbottom)
    assert_equal([105, 140], r1.centerbottom(false))
    assert_equal([100, 130], r1.leftmiddle)
    assert_equal([100, 130], r1.leftmiddle(false))
    assert_equal([100.0, 130.0], r1.leftmiddle(false))
    assert_equal([109, 130], r1.rightmiddle)
    assert_equal([110, 130], r1.rightmiddle(false))
    assert(r1.person?)
    assert(!r1.comment?)
    assert(!r1.unidentified?)
    assert("R1", r1.string)
  end

  def test_line1
    line1 = Kzd::Line.new(x1: 100, y1: 100, x2: 200, y2: 100)
    line2 = Kzd::Line.new(ary: [98, 102, 98, 200])

    assert(line1.horizontal?)
    assert(!line1.vertical?)
    assert(!line2.horizontal?)
    assert(line2.vertical?)

    # L字連結の判定
    assert_equal([98, 100], line1.intersect(line2))
    assert_equal([98, 100], line2.intersect(line1))

    # T字連結の判定
    line2.y1 -= 50
    line2.y2 -= 50
    assert_equal([98, 52, 98, 150], line2.to_a)
    assert_equal([98, 100], line1.intersect(line2))
    assert_equal([98, 100], line2.intersect(line1))

    # 十字連結の判定
    line2.x1 += 50
    line2.x2 += 50
    assert_equal([148, 52, 148, 150], line2.to_a)
    assert_equal([148, 100], line1.cross(line2))
    assert_equal([148, 100], line2.cross(line1))
  end

  def test_line2
    # 横線どうしの連結判定
    line1 = Kzd::Line.new(x1: 100, y1: 100, x2: 200, y2: 100, tolerance: 2)
    line2 = Kzd::Line.new(ary: [202, 98, 298, 98], tolerance: 3)

    assert(line1.horizontal?)
    assert(!line1.vertical?)
    assert(line2.horizontal?)
    assert(!line2.vertical?)

    # @toleranceは呼び出し元オブジェクトの値を使用しているため
    # 「line1は，line2と連結しない」「line2は，line1と連結する」が
    # 起こり得る
    assert_nil(line1.overlap(line2))
    assert_equal([201, 99], line2.overlap(line1))

    # オーバーラップ（同じ方向の線分の重なり）
    line2.x1 -= 50
    line2.x2 += 50
    assert_equal([152, 98, 348, 98], line2.to_a)
    assert_equal([224, 99], line1.overlap(line2))
    assert_equal([224, 99], line2.overlap(line1))
  end

  def test_line3
    # []を用いたアクセス
    line1 = Kzd::Line.new(x1: 100, y1: 110, x2: 200, y2: 110)

    assert_equal(100, line1[0])
    assert_equal(110, line1[1])
    assert_equal(200, line1[2])
    assert_equal(110, line1[3])
    assert_equal(100, line1.first)
    assert(line1[1] == line1.last)
    line1[0] += 2
    line1[2] -= 2
    assert_equal(102, line1[0])
    assert_equal(198, line1[2])
    line1[1] += 2
    line1[3] += 2
    assert_equal(112, line1[1])
    assert_equal(112, line1[3])
    assert(line1.horizontal?)
    assert(!line1.vertical?)
  end
end
