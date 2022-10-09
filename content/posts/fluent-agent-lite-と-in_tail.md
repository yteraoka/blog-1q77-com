---
title: 'fluent-agent-lite と in_tail'
date: Thu, 31 Jan 2013 14:35:58 +0000
draft: false
tags: ['fluentd', 'perl', 'ruby']
---

ログの収集にそろそろ fluentd を使おうかなと思って、fluent-agent-lite だとフォーマットを変えずに集められそうだという事で見てみたのだが、tail -F で読み出してるだけだから再起動すると停止中のログを取りこぼすとか、ログがあまり出ない場合は最後の10行が再度送られるとか、そういうのに寛容なデータだったら良いのだけどそうではない場合ちょっとつらいかなと思った。in\_tail.rb はどこまで処理したかを position ファイルに保存できるので続きから始められるとか、そうでなくてもファイルの末尾から読み出されるとか気を使ってあるので出来ればこっちかなと。ただし、次のように正規表現で全行 parse するってのは確かに辛いかな。

> みんな大好きfluentdはたいへん便利ですが、ログの収集＆集約だけをしたい、というときにちょっとオーバースペック気味のところがあります。特に in\_tail はログの読み込みと同時に parse をする仕組みになっており、まあログが書かれた場所ならparseのルールもわかってるでしょ、というところは合理的なものでもあるのですが、loadavgが高いサーバでそういうことをするのは正直にいってなかなか厳しいです。 [#fluentd 用ログ収集専用のエージェント fluent-agent-lite 書いた](http://d.hatena.ne.jp/tagomoris/20120314/1331716214)

ということで

```
type tail
format /^(?.*)$/ 
```

がどれくらいの負荷なのかを次のコードで試してみた

```ruby
require 'benchmark'

lines = []
f = open(ARGV[0])
while line = f.gets
    lines.push line.chomp
end
f.close

regexp = Regexp.new('^(?.*)$')

n = 1000
Benchmark.bm do |x|
  x.report("asis:  ") {
    (1..n).each {
      lines.each { |line|
        val = line
      }
    }
  }
  x.report("regexp:") {
    (1..n).each {
      lines.each { |line|
        m = regexp.match(line)
        val = m['message']
      }
    }
  }
end 
```

1,000行のログを1,000回ループさせた場合

```
       user     system      total        real
asis:    0.080000   0.000000   0.080000 (  0.081076)
regexp:  7.590000   0.000000   7.590000 (  7.592521)
```

という結果、正規表現使わずにただ読んだ行をそのまま変数に入れてあげれば結構負荷を抑えられそうです。そこで parse.rb に patch を当ててみたのです。

```diff
--- parser.rb.orig	2012-12-07 09:13:42.000000000 +0900
+++ parser.rb	2013-02-01 16:48:47.435270316 +0900
@@ -147,6 +147,18 @@
     end
   end
 
+  class AsisParser
+    include Configurable
+
+    config_param :key, :string, :default => "message"
+
+    def call(text)
+      record = {}
+      record[@key] = text
+      return Engine.now, record
+    end
+  end
+
   class ApacheParser
     include Configurable
 
@@ -205,6 +217,7 @@
     'json' => Proc.new { JSONParser.new },
     'tsv' => Proc.new { TSVParser.new },
     'csv' => Proc.new { CSVParser.new },
+    'asis' => Proc.new { AsisParser.new },
     'nginx' => Proc.new { RegexpParser.new(/^(?[^ ]*) (?[^ ]*) (?[^ ]*) \[(?[^\]]*)\] "(?\S+)(?: +(?[^ ]*) +\S*)?" (?`[^ ]*) (?[^ ]*)(?: "(?[^"]*)" "(?[^"]*)")?$/,  {'time_format'=>"%d/%b/%Y:%H:%M:%S %z"}) },
   }` 
```

これで

```
type tail
format asis
key message
```

として fluent-plugin-file-alternative で保存してやれば元ファイルのフォーマットのままログの収集ができます。 初 PullRequest してみた。'message' 固定のところは keys で指定できるようにしたほうが良かったかな。 2013-02-01 更新 key で json の key を指定できるようにしてみました。
