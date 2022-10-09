---
title: 'fluentd の out_file でファイル数を減らしたいなら append を使う'
date: Sun, 15 May 2016 08:48:29 +0000
draft: false
tags: ['fluentd']
---

td-agent-2.3.1-0.el6.x86\_64 (v0.12.20) で確認 fluentd の [out\_file](http://docs.fluentd.org/articles/out_file) は [TimeSlicedOutput](https://github.com/fluent/fluentd/blob/v0.12.20/lib/fluent/output.rb#L476) を継承して作られており、日別や時間別（[time\_slice\_format](http://docs.fluentd.org/articles/out_file#timesliceformat) で指定可能）にファイルを出力できるようになっています。

{{< figure src="out_file-path.png" link="http://docs.fluentd.org/articles/out_file#path-required" >}}

デフォルトで file buffer となっており buffer を flush する際に最終的なファイルに保存されます。flush される buffer ファイルがそのまま最終的なファイルとなるため、勝手にこれは rename されているのだろうと思ってました。
buffer\_chunk\_limit のデフォルトは 8MB でこのままだと1GBあたり128個というファイル数になってしまってちょっと多すぎるなということで 500MB まで増やしてみたのです。

そうすると0時過ぎにすごく重くなるという現象が発生...
ありゃ？なんでじゃろ？もしかして と思って確認したら rename だと思ってたところはバッファーファイルから読み出して保存先にまるっと書き出していたのです。数百MBのコピーがガンガン走ってたのです。そりゃ重い。
まず 'b' + id がファイル名に入った buffer に書き、queue に入れる際に 'b' が 'q' のファイルに rename されて flush 時にコピー処理がされるようです。

てなことなので、out\_file で buffer\_chunk\_limit を大きくするのはよろしくないようです。今回の目的はあまりファイル数を大きくしたくないという理由だったので [append](http://docs.fluentd.org/articles/out_file#append) を使うのが良さそうです。buffer\_chunk\_limit を小さくして append を有効にする。ファイルへの保存が最終目的ならいっそのこと、buffer\_type を memory にしてしまった方が良いのかもしれない。

{{< figure src="out_file-append.png" link="http://docs.fluentd.org/articles/out_file#append" >}}

out\_file で num\_threads が使えるのかどうか知らないけれど、もし使えるとしたら append と一緒には使わない方が良いかもしれない buffer からのコピーは行単位ではない（16KB単位で read, write しているみたい）ようなので複数 thread で同じファイルに追記すると壊れる行がでそう。

また、append を使う場合、そのファイルはすべての append まで不完全なままとなる。まあ、buffer からのコピーが一時ファイルからの rename じゃないから append でなくてもそのファイルはコピーが完了してるのかどうかファイルの存在確認だけでは判断できないが。
