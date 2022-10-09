---
title: 'PukiWiki から DokuWiki にデータ移行'
date: Mon, 15 Apr 2013 15:13:20 +0000
draft: false
tags: ['Perl', 'dokuwiki', 'pukiwiki']
---

PukiWiki から DokuWiki にデータ移行するメモです。 移行されるかたは是非[続編](/2013/04/migrating-from-pukiwiki-to-dokuwiki-2/)もご覧ください。

### DokuWiki Plugiin

DokuWiki は plugin なしでは PukiWiki よりも表現力が劣るので、次の Plugin を導入しました。

* [definitions plugin](https://www.dokuwiki.org/plugin:definitions)（<dt>, <dd> 対応）
* [indexmemu plugin](https://www.dokuwiki.org/plugin:indexmenu)（ls(), ls2() 対応）
* [fontsize plugin](https://www.dokuwiki.org/plugin:fontsize)（&size(n){str}; 対応）
* [color plugin](https://www.dokuwiki.org/plugin:color)（&color(xxx){str}; 対応）

### ファイル名の命名規則

PukiWiki と DokuWiki ではファイル名の命名規則が異なります。

* PukiWiki はページ名を EUC-JP で、アルファベットも記号も込で全部を16進のコードにしてしまいます
* 「/」も16進にするため、wiki ディレクトリにフラットに全てのファイルが配置されます
* DokuWiki ネームスペースを「/」で区切るため、ネームスペースがディレクトリになります
* 文字コードは UTF-8 で、記号（マルチバイトのものも一部含む）は「\_」に置き換え、アルファベットは小文字に統一します
* 連続する「\_」はひとつにまとめ、ディレクトリ、ファイル名の末尾の「\_」は削ります
* マルチバイト文字は URL エンコードされます。EUC-JP から UTF-8 への変更でほぼ2バイトだったものが3バイト以上になり、ただの HEX だったものが「%」+ HEX となり50%増量で、日本語ページ名のファイル名は結構な長さになります
* 256バイトを超えて、そのままでは移行できないページが発生しました
* アルファベットばかりのページ名であれば短くなります

PukiWiki も DokuWiki も拡張子「.txt」が付きます。 PHP で dokuwiki のファイル名生成関数を使うのが素直だと思いますが、PHP得意じゃないのでデータの変換処理書くのに時間がかかりそうだったから Perl で書きました。

### script

```
./puki2doku.pl -C -S -I \
  -s pukiwiki/wiki -d dokuwiki/data/pages
```

綺麗なコードではないですが、公開しておきます。 [puki2doku.pl](https://gist.github.com/yteraoka/5382741) 2013/04/19 いくつか Bug を修正して、[Git](https://github.com/yteraoka/puki2doku) に移しました。

* Table Cell の色付けには対応してません
* FrontPage を start に置換します
* 「- - - -\\n#contents\\n- - - -\\n」という私がよく使っていた TOC のためのコードを消す特殊処理が入ってます
* touch コマンドで元のファイルの timestamp をコピーします

### 添付ファイル

対応してません。（やりかけた形跡が残ってますけど...） 後に対応しました。「[（続）PukiWiki から DokuWiki にデータ移行](/2013/04/migrating-from-pukiwiki-to-dokuwiki-2/)」

### 検索インデックス

データ移行後に

```
cd dokuwiki/bin
php indexer.php
```

で検索インデックスを作成してください。 Web からではなくファイルを直接変更した場合はこの処理が必要です。 今日はこれまで。 2013/04/20 追記 fontsize plugin は color や bold 装飾と入れ子で使う場合一番内側に置かないと他の装飾が効かなし「\*\*」とかがそのまま表示されてしまう・・・これは厄介。fontsize は無効にするかな。
