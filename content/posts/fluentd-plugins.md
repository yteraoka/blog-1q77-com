---
title: '逆引き Fluentd plugins （更新あり）'
date: Fri, 06 Dec 2013 15:03:48 +0000
draft: false
tags: ['Advent Calendar', 'fluentd']
---

ワイワイ！ この投稿は [Fluentd Advent Calendar 2013](http://qiita.com/advent-calendar/2013/fluentd) の7日目の記事です。 [前日](http://orihubon.com/blog/2013/12/06/fluentd-multiprocess-input-plugin/) 10ヶ月ほど前、私が [@tagomoris](https://twitter.com/tagomoris) 氏のブログをコピペしながら人生初 rubygem として [fluent-plugin-tail-asis](https://github.com/yteraoka/fluent-plugin-tail-asis) を書いた時、[http://fluentd.org/plugin/](http://fluentd.org/plugin/) の plugin はまだ2桁だったんじゃないかと思うのですが、今覗いてみるとなんと 209 です。もう全部を調べるわけにはいかない量です。Fluentd プラグインは簡単に書けることから調べるの面倒だから自分で書いちゃえってなりがちな気もします。実際、私も他では利用価値の無さそうな plugin はちょろっと書いて /etc/td-agent/plugin/ に放り込むだけだったりします。private な Git リポジトリには入っていますけども。 そこで、今回はよく使われてそうなプラグインを「こんなことをしたい場合にはこれ」っていうかたちで紹介したいと思います。とは言うものの、そんなにいろんな使い方してないので自分が使うかもなあってのをいくつかピックアップして紹介してみます。 4日目の [@yoshi\_ken](https://twitter.com/yoshi_ken) さんの「[Fluentdが流行る理由がいま分かる、10の実践逆引きユースケース集](http://y-ken.hatenablog.com/entry/fluentd-case-studies)」っていうタイトルを見て「やべっ！逆引きだっ！」って思って焦りました。

### MongoDB に保存したい

[fluent-plugin-mongo](https://github.com/fluent/fluent-plugin-mongo) MongoDB 一番人気みたいです。私、全然知りませんけど。 データサイズを物理メモリより小さくしておけばイケてるらしいです。 [Store Apache Logs into MongoDB](http://docs.fluentd.org/articles/apache-to-mongodb)

### ログの内容によって振り分ける、フィルターする

[fluent-plugin-rewrite-tag-filter](https://github.com/fluent/fluent-plugin-rewrite-tag-filter) 正規表現でマッチさせて tag を書き換えることによって送り先などを振り分けることができます。 不要なログは type null に送って捨てることができます。大変便利です。 レコードの内容によらず、ルーティングするには [fluent-plugin-route](https://github.com/tagomoris/fluent-plugin-route) が使えるようです。

### Elasticsearch に保存して Kibana で可視化したい

[fluent-plugin-elasticsearch](https://github.com/uken/fluent-plugin-elasticsearch) Kibana 便利ですね。 Map 機能があって2桁の国コードを使って地図上に表現できます。[fluent-plugin-geoip](https://github.com/y-ken/fluent-plugin-geoip) を使うことでIPアドレスから国コードを得ることができます。組み合わせて使うと便利です。 [Free Alternative to Splunk Using Fluentd](http://docs.fluentd.org/articles/free-alternative-to-splunk-by-fluentd)

### ログの各行をそのまま送りたい・集めたい

```
format /^(.\*)$/ 
```

とすればずっと昔からできたのですが、今は format none と指定することで正規表現を使わず処理できて CPU にやさしくなります。0.10.39 よりも前の fluentd を使ってる場合は拙作の [fluent-plugin-tail-asis](https://github.com/yteraoka/fluent-plugin-tail-asis) が使えます。これで JSON のひとつのキーに行がまるごと入ります。しかし、これを type file で書き出すと。

```
timestamp tag {"key":"line"}
```

となってしまうので [fluent-plugin-file-alternative](https://github.com/tagomoris/fluent-plugin-file-alternative) を使ってファイルに書き出します。指定のキーの値だけを1行として書きだしてくれます。

### ログを AWS S3 に保存したい

[fluent-plugin-s3](https://github.com/fluent/fluent-plugin-s3) を使います。前項の行をそのまま送るという用途では [fluent-plugin-s3-alternative](https://github.com/studio3104/fluent-plugin-s3-alternative) が使えます。AWS のアクセスキーなどを設定ファイルに書きたくない、リポジトリに登録したくないという場合は [fluent-plugin-config\_pit](https://github.com/naoya/fluent-plugin-config_pit) が使えます。 [Store Apache Logs into Amazon S3](http://docs.fluentd.org/articles/apache-to-s3)

### ファイル名に日付を含むログを tail したい

[fluent-plugin-tail-ex](https://github.com/yosisa/fluent-plugin-tail-ex) を使うことで glob(\*) や strftime 記号を使ったファイルの指定を行うことができます。 ただし、 pos\_file が使えません。また refresh\_interval を短めに設定しておかないと refresh 後のログしか拾ってくれないので、最大でこの秒数のログを読み込むことができません。 ログを取りこぼしたくない場合は自前で symbolic link を張り直す処理を組んだほうが良いと思います。  
2014-02-07更新  
作者の方に大変申し訳無い。再度確認したら read\_all っていう設定があって、新しいファイルは先頭から読んでくれるし、pos\_file も有効ですね。私はなんでこんな大きな勘違いしたんだろうか？

### サーバー間の通信を暗号化したい

インターネット越しにログを forward で送るときに気になるポイントですね。[fluent-plugin-secure-forward](https://github.com/tagomoris/fluent-plugin-secure-forward) で通信を暗号化できるようです。

### 指定の条件にマッチしたら通知を行いたい

ログから危険な兆候を見つけたりしたらメールやIRC、電話で通知したいという場合には [fluent-plugin-filter](https://github.com/muddydixon/fluent-plugin-filter) を使って、条件を設定し、通知に使いたいプラグインに渡すと良いみたいです。ikachan を使って IRC に通知する [fluent-plugin-ikachan](https://github.com/tagomoris/fluent-plugin-ikachan) とか、メールで通知する [fluent-plugin-mail](https://github.com/u-ichi/fluent-plugin-mail) とかが使えそうです。 Twillio で電話をかけるっていうのもできそうです。[fluent-plugin-twilio](https://github.com/y-ken/fluent-plugin-twilio) これがそのまま使えるかどうかはわからない。 [Splunk-like Grep-and-Alert-Email System Using Fluentd](http://docs.fluentd.org/articles/splunk-like-grep-and-alert-email)

### 肥大化しすぎた config ファイルをなんとかしたい

きまったパターンの設定がつらつらと並んでいる場合は [fluent-plugin-forest](https://github.com/tagomoris/fluent-plugin-forest) を使うことでシンプルにできるかもしれません。

### Twitter を Input / Output に使いたい

[fluent-plugin-twitter](https://github.com/y-ken/fluent-plugin-twitter) 今回、プラグインをつらつら眺めていて、これは面白そうだなと思いました。

### HTTPのステータスコードとか指定のパターン毎に行数をカウントしたい

[fluent-plugin-numeric-counter](https://github.com/tagomoris/fluent-plugin-numeric-counter) がHTTP の Status 毎とか、200番台、300番台、400番台、500番台をそれぞれ数えるとかで使えるようです。この結果を [fluent-plugin-growthforecast](https://github.com/tagomoris/fluent-plugin-growthforecast) で GrowthForcast に渡せばグラフ化も簡単。でも、この用途だと今時は Kibana の方が良いかも。

### レスポンスタイムのタイル値を計測したい

[fluent-plugin-numeric-monitor](https://github.com/tagomoris/fluent-plugin-numeric-monitor) を使うことでサービスのレスポンスタイムのタイル値を計算することができます。98%タイル値とか重要ですよね。これはまだ Kibana ではできないので [fluent-plugin-growthforecast](https://github.com/tagomoris/fluent-plugin-growthforecast) と組み合わせるのが良さそうです。 min / max / avg / sum も出せます。

### FortiGate のログを FortiAnalyzer を買わずに可視化したい

そんな奇特な方はこちらのブログをどうぞ。「[Fluentd + Kibana3 で FortiAnalyzer いらず](/2013/10/fluentd-kibana3-fortianalyzer/)」、「[続オレオレFortiAnalyzer](/2013/10/fluentd-kibana3-fortianalyzer-2/)」

* * *

監視や可視化は [@sonots](https://twitter.com/sonots) さんのブログに大変わかりやすくまとめられています。

* [sonots:blog : FluentdとGrowthForecastを使った可視化 〜 Haikanko OSS化への道(4)](http://blog.livedoor.jp/sonots/archives/25189820.html)
* [sonots:blog : fluentdを使ったログ監視 〜 Haikanko OSS化への道(3)](http://blog.livedoor.jp/sonots/archives/25018617.html)

* * *

今回のネタのきっかけは↓コレです。おぉ、こんな便利なプラグインがあったの知らなかったよってことで。

{{< twitter user="yteraoka" id="395416927729754112" >}}

明日はこの [@repeatedly](https://twitter.com/repeatedly) さんんで〜す。

* * *

ところで、 fluentd の config parser はコメントとともに行末の空白を取り除いてしまうため、LTSV で

```
label_delimiter ": "
```

てなことができずに困ってしまいました。こういうのどうですかね？手を抜きすぎですかね？

```diff
# diff -u /usr/lib64/fluent/ruby/lib/ruby/gems/1.9.1/gems/fluentd-0.10.39/lib/fluent/config.rb /tmp/config.rb
--- /usr/lib64/fluent/ruby/lib/ruby/gems/1.9.1/gems/fluentd-0.10.39/lib/fluent/config.rb	2013-09-25 05:23:14.000000000 +0900
+++ /tmp/config.rb	2013-12-05 23:10:22.933934714 +0900
@@ -181,6 +181,7 @@
           elsif m = /^([a-zA-Z0-9_]+)\s*(.*)$/.match(line)
             key = m[1]
             value = m[2]
+            value.gsub!(/^"(.*)"$/, '\1') or value.gsub!(/^'(.*)'$/, '\1')
             if allow_include && key == 'include'
               process_include(attrs, elems, value)
             else
```
