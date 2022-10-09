---
title: 'fluentd / td-agent がいろいろ便利になってた'
date: Tue, 15 Jul 2014 14:25:25 +0000
draft: false
tags: ['fluentd', 'td-agent']
---

しばらくぶりに fluentd / td-agent 案件の対応をしたら、いろいろ機能追加されてたりして便利になっていたのでメモ。（2014/7/19 出力フォーマット指定のところに追記しました）

* [The td-agent ChangeLog](http://docs.treasuredata.com/articles/td-agent-changelog)
* [fluentd ChangeLog](https://github.com/fluent/fluentd/blob/master/ChangeLog)

td-agent 1.1.18 で rewrite-tag-filter が同梱されるようになった
-------------------------------------------------

これまで追加で

```
$ sudo fluent-gem install fluent-plugin-rewrite-tag-filter
```

してたけど不要になりました。install しようと思って実行したらもう入ってるよって言われた...

td-agent 1.1.19 で tail-ex が不要になった
---------------------------------

td-agent 1.1.19 で fluentd v0.10.45 となったので tail-ex の merge が反映されました。

> Release 0.10.45 - 2014/03/28
> 
> *   in\_tail: Merge in\_tail\_ex and in\_tail\_multiline features

in\_tail の `path` におもむろに strftime の%記号を入れてあげれば動作します。 `read_from_head` を `true` にすると初回はファイルの先頭から読んでくれます。

td-agent 1.1.20 で out\_file が format 指定可能になった
---------------------------------------------

fluentd v0.10.49 で out\_file が TextFormatter を使って出力フォーマットを指定できるようになりました。

> *   out\_file: Add format option to support various output data format

`format` で指定可能なのはいまのところ

out\_file

これまで通りのフォーマットです。time, tag の出力を停止することも可能で、json に含めることも可能。デフォルトでは `TIME<TAB>TAG<TAB>JSON` となりますが `output_time`, `output_tag` を `false` にすることで出力させないこともできます。`include_time_key`, `include_tag_key` を `true` にすることで `time` と `tag` を JSON に含められます

json

JSON 出力ですが out\_file で代用できそうな気もする。でも json って明示してある方がわかりやすいですね。`out_file` と違って1行がまるっと JSON なので Parse がより楽ちんですね。time や `tag` を出力するには `include_time_key`, `include_tag_key` を `true` にする必要があります

ltsv

LTSV で書き出せます。`include_tag_key`, `tag_key`, `include_time_key`, `time_key` オプションで tag と time を含めるようにも指定できます。time は出力のフォーマットを指定可能です。

```
  type tail
  path /path/to/ltsv_log.%Y%m%d
  time_format %Y-%m-%d %H:%M:%S
  tag ltsv.test
  format ltsv
  time_key time

 type file
  path /apps/tmp/ltsv_test_file
  format ltsv
  include_time_key true
  time_format %Y-%m-%dT%H:%M:%S%z 
```

このようにすることで、LTSV を LTSV のまま書き出すことができます。次の `single_value` と違い、各項目でフィルタリングやルーティングが行いやすいですね

single\_value

[fluent-plugin-file-alternative](https://github.com/tagomoris/fluent-plugin-file-alternative) の代わりに使えるようです。in\_tail で `format none` として読みだしたデータを書き出すのに適しています。ログファイルの1行1行をそのまま集めたい場合ですね

```
  type tail
  path /path/to/log.%Y%m%d
  format none
  #message_key message
  tag test.access

 type file
  file /path/to/out_file
  format single_value
  #message_key message 
```

key の名前はどちらもデフォルトが `message` で `message_key` パラメータで指定可能です。

out\_file の format はまだ GitHub の code を眺めただけで試してない。 out\_file 関連では daemon モードでの `umask 0` をなんとかしてほしいなぁ。 Fluentd も Ansible みたいにドキュメントが code に入ってると嬉しいなぁと思いました。 「このオプションはバージョンxxで追加されました」とか入っているし、`ansible-doc` コマンドも便利ですよね。それでも Ansible も code 読まないとわからないことも沢山あるけど。
