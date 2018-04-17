#!/usr/bin/ruby

require "open-uri"
require "fileutils"
require_relative "../lib/kzd.rb"

def init_zip
  # rubyzipライブラリを読み込む．できなかった場合には
  # $use_zipをfalseにする（zip/unzipコマンドで処理する）
  if $use_zip.nil?
    $use_zip = true
    begin
      require "zip"
    rescue LoadError
      $use_zip = false
    end
  end

  $use_zip
end

def init_hideyoshi_files
  # 画像とテキストのファイルを用意する
  make_image_files
  make_text_files
end

def make_image_files
  # 画像ファイルを用意する

  # すでに画像ファイルがあれば何もせず帰る
  return if test(?f, File.join("img", "p1.jpg")) &&
    test(?f, File.join("img", "p2.jpg")) &&
    test(?f, File.join("img", "p3.jpg"))

  # zipファイルがなければメッセージを出力して終了する
  zipfile = "200021823.zip"
  if !test(?f, zipfile)
    puts <<'EOS'
Sorry, a ZIP file (200021823.zip) is not found.
Please download it by getting access to:
http://codh.rois.ac.jp/pmjt/book/200021823/
EOS
    exit(1)
  end

  imgdir = "img"
  if !test(?d, imgdir)
    FileUtils.mkdir_p(imgdir, verbose: true)
  end

  # 各画像ファイルの作成
  tmp_file_a = []
  imgfile1 = File.join(imgdir, "p1.jpg")
  if !test(?f, imgfile1)
    puts "making #{imgfile1}..."
    imgfile1tmp = File.join(imgdir, "00171.jpg")
    tmp_file_a << imgfile1tmp
    extract_from_zip(zipfile, "200021823/image/200021823_00171.jpg", imgfile1tmp)
    command = "convert #{imgfile1tmp} -crop 2400x3400+1024+1200 -resize '50%' -quality 90 #{imgfile1}"
    puts command
    system command
  end
  imgfile2 = File.join(imgdir, "p2.jpg")
  imgfile3 = File.join(imgdir, "p3.jpg")
  if !test(?f, imgfile2) || !test(?f, imgfile3)
    puts "making #{imgfile2}..."
    imgfile2tmp = File.join(imgdir, "00172.jpg")
    tmp_file_a << imgfile2tmp
    extract_from_zip(zipfile, "200021823/image/200021823_00172.jpg", imgfile2tmp)
    command = "convert #{imgfile2tmp} -crop 2400x3400+3643+1200 -resize '50%' -quality 90 #{imgfile2}"
    puts command
    system command
    command = "convert #{imgfile2tmp} -rotate -2 -crop 2400x3400+1000+1254 -resize '50%' -quality 90 #{imgfile3}" # 反時計回りに2度回転する処理で時間がかかる
    puts command
    system command
  end

  if !tmp_file_a.empty?
    FileUtils.rm(tmp_file_a, verbose: true)
  end
end

def extract_from_zip(zipfile, targetfile, savefile = nil)
  # zipファイルから特定のファイルだけを取得して保存する

  savefile ||= File.basename(targetfile)

  if $use_zip
    Zip::File.open(zipfile) do |z|
      entry_a = z.glob(targetfile)
      return false if entry_a.empty?
      entry = entry_a.first
      entry.extract(savefile) {true}
    end
  else
    dir = File.dirname(savefile)
    command = "unzip -o #{zipfile} #{targetfile} -d #{dir}"
    puts command
    system command
    FileUtils.mv(File.join(dir, targetfile), savefile, verbose: true)
  end

  true
end

def make_text_files
  # 3つのテキストファイルを用意する

  textdir = File.join("text")
  if !test(?d, textdir)
    FileUtils.mkdir_p(textdir, verbose: true)
  end

  make_text_file(File.join(textdir, "p1.txt"), <<'EOS1')
秀吉 1032, 122; 111 x 178
不詳其父　木下藤吉　又号羽柴筑前守 1093, 300; 74 x 1222
後自改姓始称豊臣 1001, 298; 78 x 571
関白從一位太政大臣 932, 296; 68 x 621
慶長三年八月十八月薨 848, 300; 71 x 688
秀長 633, 192; 110 x 178
美濃守　大和大納言 698, 417; 67 x 719
女子 335, 198; 102 x 170
武蔵守三位法卬一路妻 435, 407; 76 x 733
関白秀次毋 353, 411; 60 x 363
一路初名弥助尾 385, 799; 52 x 476
州海部郡人也 344, 786; 41 x 419
秀次弟曰小吉号岐阜少将 274, 407; 66 x 827
女子 20, 189; 100 x 178
南明院殿 66, 407; 76 x 290
EOS1

  make_text_file(File.join(textdir, "p2.txt"), <<'EOS2')
秀俊 1024, 177; 99 x 195
大和中納言 1076, 389; 67 x 365
實三位法卬子 991, 394; 74 x 429
女子 722, 187; 106 x 181
森美作守妻 754, 393; 81 x 370
女子 426, 176; 107 x 187
毛利甲斐守妻 468, 393; 69 x 431
秀次 77, 172; 108 x 182
関白内大臣　初為三好山城守養子故号 140, 394; 73 x 1261
三好孫七郎　實三位法卬子　秀吉養子 74, 407; 70 x 1237
EOS2

  make_text_file(File.join(textdir, "p3.txt"), <<'EOS3')
秀秋 989, 185; 102 x 170
金吾　後号筑前中納言 1056, 407; 72 x 747
實木下肥後守家定子　秀吉養子 980, 415; 70 x 1006
家定者秀吉公妻之兄也 904, 417; 74 x 706
棄 598, 192; 82 x 104
幼卒去 637, 339; 78 x 207
秀頼 190, 192; 95 x 173
右大臣從二位 255, 413; 65 x 426
元和元年五月亡 168, 420; 69 x 486
EOS3
end

def make_text_file(filename, lines)
  # 位置情報付きテキストとしてファイルに保存する

  open(filename, "w") do |f_out|
    lines.each_line do |line|
      if /(\S+)\s+(\d+)\D+(\d+)\D+(\d+)\D+(\d+)/ =~ line
        content, hpos, vpos, width, height = $1, $2.to_i, $3.to_i, $4.to_i, $5.to_i
        f_out.print 'String CONTENT="%s" WIDTH="%d" HEIGHT="%d" HPOS="%d" VPOS="%d"' % [content, width, height, hpos, vpos] + "\r\n"
      elsif /^$/ !~ line
        print "skipped: " + line
      end
    end
  end
end

def make_zip_file
  # hideyoshi_result.zipを作成する
  s = <<'EOS'
img/p1.jpg initial-p1.jpg
img/p2.jpg initial-p2.jpg
img/p3.jpg initial-p3.jpg
img/result/p1.jpg result-p1.jpg
img/result/p2.jpg result-p2.jpg
img/result/p3.jpg result-p3.jpg
text/p1.txt alto-p1.txt
text/p2.txt alto-p2.txt
text/p3.txt alto-p3.txt
r/result1.txt result1.txt
r/result2.txt result2.txt
EOS
  dir = "hideyoshi_result"
  zipfile = "#{dir}.zip"

  if !test(?d, dir)
    FileUtils.mkdir(dir, verbose:true)
  end
  file_a = s.strip.split(/\n/).map {|item|
    a = item.split(/ /)
    a[1] = File.join(dir, a[1])
    a
  }

  file_a.each do |file_from, file_to|
    FileUtils.mv(file_from, file_to, verbose: true)
  end

  if $use_zip
    Zip::File.open(zipfile, Zip::File::CREATE) do |z|
      Dir.glob(File.join(dir, "*")) do |file|
        z.add(file)
        # z.add(file, file)
      end
    end
  else
    command = "zip -r #{zipfile} #{dir}"
    puts command
    system command
  end
end

def report(man)
  # テキストファイルおよびPStoreファイルを作成
  extend Kzd::Reporter

  dir = "r"
  if !test(?d, dir)
    FileUtils.mkdir(dir, verbose: true)
  end

  ld_a, stat_a = setup_ld(man, true)
  open(File.join(dir, "result1.txt"), "w") do |f_out|
    f_out.print stat_a.join("\r\n") + "\r\n"
  end
  dat = save_pstore(man, File.join(dir, "result2.pstore"), ld_a)
  report_all(dat, File.join(dir, "result2.txt"))
end

def cleanup(dir_a)
  # 中間ファイル削除
  dir_a.each do |dir|
    FileUtils.rm_r(dir, secure: true)
  end
end

#### main

if String === ARGV[0] && test(?d, ARGV[0])
  Dir.chdir(ARGV[0])
end

# すでにあるディレクトリは，あとで削除しない
tmp_dir_a = %w(text img r hideyoshi_result).map {|dir|
  test(?d, dir) ? nil : dir
}.compact

init_zip
init_hideyoshi_files

man = Kzd::Manager.new

# 画像および位置情報付きテキストのファイル名をmanへ
filename_img_a = Dir.glob("img/p*.jpg").sort
filename_text_a = Dir.glob("text/p*.txt").sort
filename_img_a.length.times do |i|
  key = "豊臣秀吉譜上_#{i + 1}"
  man.add_page(Kzd::Page.new(key: key,
                             img: filename_img_a[i],
                             xml: filename_text_a[i]))
end

# 幅と高さの平均値を求めるための計算
string_count = 0
width_count = 0
height_count = 0
man.each_page do |page|
  print "."; $stdout.flush
  rp = Kzd::RegionProcessor.new(page.filename_xml)
  rp.analyze
  page.reg = rp

  string_count += rp.strings.length
  width_count += rp.strings.map {|r| r.width}.inject(:+)
  height_count += rp.strings.map {|r| r.height}.inject(:+)
end
puts

# 人物名と付随情報の判別（幅と高さに基づく）
person_box = [width_count.to_f / string_count, -1, 999999, height_count.to_f / string_count]
man.each_page do |page|
  page.reg.set_person_by_size(person_box)
  page.reg.set_comment

  puts "#{page.key} [#{page.filename_image}]:"
  # 登録順に各文字列を出力（未識別も出力する）
  page.reg.each_string do |reg|
    print "  #{reg.string}"
    print "  (person)" if reg.person?
    print "  (comment)" if reg.comment?
    puts
  end
end


# 幅と高さに基づく誤判別の修正
reg = man.pages[1].reg.strings[4]
man.each_page do |page|
  page.reg.modify_region_type(distx: 10, disty: 10, vote: 2)
end

# 各位置情報付きテキストに対して文字列取得
man.each_page do |page|
  print "."; $stdout.flush
  rp = Kzd::RegionProcessor.new(page.filename_text)
  rp.analyze

  # 人物名と付随情報の判別（字数に基づく）
  rp.set_person_by_regexp(/\A..?\Z/)
  rp.set_comment

  # 人物と付随情報の対応付け（距離に基づく）
  rp.correspond_person_comment

  page.reg = rp
end

# 対応付けの修正
rp1 = man.pages[0].reg
rp1p = rp1.search_idx("秀吉")
rp1c = rp1.search_idx("慶長三年八月十八月薨")
rp1.set_person_comment(rp1p, rp1c)

# 画像処理の対象領域
bbox_a = [
  [12, 51, 1182, 1674],
  [22, 79, 1199, 1661],
  [157, 105, 1199, 1446]
]

# 線分修正
mod = Psych.load(<<'EOS')
p1:
  - del_h: 74x21+1047+1614
  - merge_v: 32x1342+1065+322
  - expand_up: 50x1368+1056+300
p2:
  - del_v: 22x139+1178+393
  - del_v: 33x61+932+1627
  - del_v: 30x43+333+1657
  - del_h: 46x102+1154+405
  - del_h: 72x68+1128+187
p3:
  - del_v: 80x106+450+997
  - del_v: 31x571+0+1129
  - del_h: 87x82+103+235
  - del_h: 31x571+0+1129
EOS

# 認識結果を描画
man.each_page_with_index do |page, i|
  ld = Kzd::LineDetector.new(img: page.filename_image,
                             xml: page.filename_xml,
                             reg: man.regs("豊臣秀吉譜上_#{i + 1}"),
                             fndir: true, bbox: bbox_a[i],
                             mono_th: 0.6, run_len: 20, run_out: 0.03,
                             all: true, draw: true, csv: true)

  ld.start
  ld.modify(mod["p#{i + 1}"])
  ld.calc_cross
  page.lin = ld

  if test(?f, ld.fn("result", :jpg))
    FileUtils.rm(ld.fn("result", :jpg), verbose: false)
  end

  ld.draw2(img_from: ld.img_in, img_to: ld.fn("result", :jpg), reg: page.reg, all: true)
end

# テキストファイルを作成
report(man)

# ZIP化
make_zip_file

# 中間ファイル削除
cleanup(tmp_dir_a)
