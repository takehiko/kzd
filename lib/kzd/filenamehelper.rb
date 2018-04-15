module Kzd
  module FilenameHelper
    # include Kzd::FilenameHelperを忘れずに

    def fn(*param)
      filename_from = @img_in
      raise if filename_from.nil?

      # nilがあれば除去
      param.compact!

      if @option_save_by_dir # 新形式
        # filename_fromをディレクトリ名とファイル名に分ける
        dir1 = File.dirname(filename_from)
        base = File.basename(filename_from)

        # 引数が2以上あれば，最後を除きサブディレクトリとする
        # そのディレクトリがなければ作る
        if param.length >= 2
          dir2 = param[0..-2].join("/")
          dir = dir1 + "/" + dir2
          dir.sub!(/^\.\//, "")
          if !test(?d, dir)
            FileUtils.mkdir_p(dir)
          end
          dir += "/"
        else
          if dir1.empty? || dir1 == "."
            dir = ""
          else
            dir = dir1 + "/"
          end
        end

        # サフィックス
        base.sub!(/\.je?pg$/i, "")
        case param.last.to_s
        when ""           # nil, ""
          suffix = ""
        when /^[_\.]/     # ".csv", "_1.jpg"
          suffix = param.last.to_s
        when /\./         # "1.jpg"
          suffix = "_" + param.last.to_s
        else
          suffix = "." + param.last.to_s
        end

        # 最終的なファイル名
        dir + base + suffix
      else # 旧形式
        filename_from.sub(/\.je?pg$/i, "") + (param.empty? ? "" : "_" + param.flatten.join("."))
      end
    end
  end
end
