---
title: 'mod_headers に note 機能が追加されました'
date: Mon, 09 Dec 2013 13:55:15 +0000
draft: false
tags: ['Apache']
---

この投稿は Apache httpd Advent Calendar 2013 ではありません... 2013-11-25 に Apache httpd 2.4.7 がリリースされました。 [CHANGES\_2.4.7](http://ftp.riken.jp/net/apache//httpd/CHANGES_2.4.7) この中に

> \*) mod\_headers: Add 'Header note header-name note-name' for copying a response headers value into a note. \[Eric Covener\]

という変更を見つけました。これは!! 「[Apache で Response Header を消しつつその値をログに書き出す](/2013/02/mod_headers-toenv/)」で書いた機能が Apache に追加されたようです。 当該部分のコードはこれ

```
case hdr_note:
    apr_table_setn(r->notes, process_tags(hdr, r), apr_table_get(headers, hdr->header));
    break;
```

私は subprocess\_env にコピーしたのですが、これは notes にコピーしていますね。 notes っていうのは module 間でデータを受け渡しできるメモ用テーブルです。 mod\_log\_config で %{VARNAME}n として書き出すことができます。「[モニカジ#3に参加してきた](/2013/03/monitoring-casual-3/)」で触れた [@kazeburo](https://x.com/kazeburo) さんの [mod\_copy\_header](https://github.com/kazeburo/mod_copy_header) もこの notes で実装されてます。（あ、Example の LogFormat のところにミスが...） mod\_headers の note は次のように使います。CGI で出力するヘッダーを扱う場合は always が必要です（これでしばらくハマりました）。Proxy だったら不要。

```
Header [always] note X-Foo foo
Header [always] unset X-Foo
LogFormat "... %{foo}n" xxx
```

Client に返したくないデータのはずなので unset をお忘れなく。返して良いヘッダーをログに書き出すだけなら %{X-Foo}o で出来ますし。

### おまけ

2.4.7 の mod\_headers には setifempty という機能も追加されていました。「Set If Empty」で名前の通りの機能ですね。

> \*) mod\_headers: Add 'setifempty' command to Header and RequestHeader. \[Eric Covener\]
