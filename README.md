# Keizu Deconstructor (Kzd)

## 何これ?

「系図画像」と，「位置情報付きテキスト」（系図画像上のどの領域に何が書かれているかを指示したテキストファイル）をもとに，親子関係・兄弟関係をはじめ情報の関連付けを行うプログラムです．

系図上で人物同士をつなぐ線分については，単純な画像処理により，認識を試みています．縦横の線が複雑に組み合わさっているほか，ページをまたぐような状況も，認識・対応付けが可能です．認識結果をもとの画像上に描く機能もあります．

## 動せる?

はい．プログラムは[Ruby](http://www.ruby-lang.org/ja/)で記述していまして，実行にはrubyコマンドを使用します．そのほか，[ImageMagick](https://www.imagemagick.org/script/index.php)も必要です（プログラムの中から，ImageMagickのconvertおよびidentifyのコマンドを呼び出しています）．これまで，Ubuntu，Windows + Cygwinで動作確認を行ってきました．Docker Hubにも登録し，イメージをダウンロードできるようにしています（[takehiko/kzd](https://hub.docker.com/r/takehiko/kzd/)）．

『豊臣秀吉譜』に収められた，3ページの系図画像を対象として，一連の処理を行い，画像とテキストを作成する，サンプルプログラムを同梱しています．シェルのほか，dockerコマンドが使える環境があれば（gitもrubyもImageMagickもインストール不要），以下の手順でhideyoshi_result.zipというファイルが作られます．

1. ブラウザで[将軍家譜 | 日本古典籍データセット](http://codh.rois.ac.jp/pmjt/book/200021823/)にアクセスし，「デジタル画像とメタデータの一括ダウンロード」を押してダウンロードを行い，200021823.zipの名前で保存します（約880MBあります）．
2. シェルのカレントディレクトリに，200021823.zipをコピーするか，200021823.zipのあるディレクトリに移動します．
3. 以下のコマンドを実行します．
- `docker pull takehiko/kzd`
- `docker run -it --rm -v $(pwd):/h takehiko/kzd ./hideyoshi.rb /h`

## 学術成果?

そうです．本プログラムは，以下にて発表した研究成果を発展させたものです．

- 永井謙也, 村川猛彦, 大澤留次郎, 宇都宮啓吾: 系図からのデータ自動取得の試み, 人文科学とコンピュータシンポジウム論文集, 情報処理学会シンポジウムシリーズ, Vol.2017, No.2, pp.15-22 (2017). http://id.nii.ac.jp/1001/00184631/

本プログラムの開発と公開に関して，2018年5月に開催の[第117回 人文科学とコンピュータ研究会発表会（情報処理学会）](http://www.jinmoncom.jp/index.php?CH117)で発表する予定です．

## 系図作成?

違います．従来の系図ソフトウェアや，系図を対象とした情報処理分野からのアプローチは，系図を「構築する(construct)こと」に主眼が置かれてきました．それに対し，本プログラムの開発にあたっては，いかにして既存の系図を「解体する(deconstruct)か」に関心を持っています．プログラム名にdeconstructorを入れたのは，そういった経緯からです．

現状では，あらゆる系図に対応できているわけではありません．例えば婚姻関係を含む系図は対象外です．将軍や，僧侶の人間関係を表した系図を，これまで主な対象としてきました．適用対象を広げること，標準的なフォーマットで保存できるようにすることなどが，今後の課題となります．
