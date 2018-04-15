#!/usr/bin/env ruby

require "test/unit"
require_relative "../lib/kzd.rb"

class ClassUsingFilenameHelper
  include Kzd::FilenameHelper

  def initialize(opt = {})
    @img_in = opt[:img] || "dir/ect/ory/test_file.jpg"
    @option_save_by_dir = opt[:bydir]
  end
  attr_reader :img_in
end

class TestFilenameHelper < Test::Unit::TestCase
  # def setup; end

  def teardown
    %w(dir 9).each do |d|
      if test(?d, d)
        system("/bin/rm -Rf #{d}")
      end
    end
  end

  def test_filename1
    # ディレクトリを分けない（test_file.jpgと同じディレクトリに
    # 他のファイルを作成する）場合のファイル名
    obj = ClassUsingFilenameHelper.new
    assert_equal("dir/ect/ory/test_file.jpg", obj.img_in)
    assert_equal("dir/ect/ory/test_file", obj.img_in.sub(/\.je?pg$/i, ""))
    assert_equal("dir/ect/ory/test_file_1.jpg", obj.fn("1.jpg"))
    assert_equal("dir/ect/ory/test_file_1.jpg", obj.fn(nil, "1.jpg"))
    assert_equal("dir/ect/ory/test_file_9.csv", obj.fn(9, :csv))
    assert_equal("dir/ect/ory/test_file_9.h.csv", obj.fn(9, "h.csv"))
    assert_equal("dir/ect/ory/test_file", obj.fn)
  end

  def test_filename2
    # ディレクトリを分ける場合のファイル名
    obj = ClassUsingFilenameHelper.new(bydir: true)
    assert_equal("dir/ect/ory/test_file.jpg", obj.img_in)
    assert_equal("dir/ect/ory/test_file_1.xbm", obj.fn("1.xbm"))
    assert_equal("dir/ect/ory/test_file_1.xbm", obj.fn(nil, "1.xbm"))
    assert_equal("dir/ect/ory/9/test_file.csv", obj.fn(9, :csv))
    assert_equal("dir/ect/ory/9/test_file_h.csv", obj.fn(9, "h.csv"))
  end

  def test_filename3
    # ディレクトリを分ける場合のファイル名
    obj = ClassUsingFilenameHelper.new(img: "test_file.jpg", bydir: true)
    assert_equal("test_file.jpg", obj.img_in)
    assert_equal("test_file_1.xbm", obj.fn("1.xbm"))
    assert_equal("test_file_1.xbm", obj.fn(nil, "1.xbm"))
    assert_equal("9/test_file.csv", obj.fn(9, :csv))
    assert_equal("9/test_file_h.csv", obj.fn(9, "h.csv"))
  end

  def test_filename4
    # サフィックスなし
    obj = ClassUsingFilenameHelper.new(bydir: true)
    assert_equal("dir/ect/ory/test_file.jpg", obj.img_in)
    assert_equal("dir/ect/ory/8/test_file", obj.fn(8, ""))
    assert_equal("dir/ect/ory/test_file.9", obj.fn(9, nil))
    assert_equal("dir/ect/ory/test_file", obj.fn(nil))
    assert_equal("dir/ect/ory/test_file", obj.fn)
  end
end
