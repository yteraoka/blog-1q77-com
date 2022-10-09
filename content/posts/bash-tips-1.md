---
title: 'Bash Tips （未定義変数）'
date: Fri, 22 Mar 2013 16:21:17 +0000
draft: false
tags: ['Bash', 'bash', 'shell script']
---

[Qiita](http://qiita.com/) の [シェルスクリプトで便利な小技](http://qiita.com/items/4f408b8b856a54e1c1b9) で **"set -u"** の解説があり

> スクリプト中で値が設定されていない変数を参照した場合に エラーメッセージを表示してスクリプトを終了させる。シェル変数や環境変数を typo した場合など、 変数に値が設定されていない事で発生する問題が回避できる。

おお、これは便利！！（root で動かす shell script で rm -fr 使うのってすごくコワイ）```
$ cat test.sh
#!/bin/sh
set -u
work\_dir=/tmp
rm -fr ${work\_dri}/\*

$ ./test.sh
./test.sh: 4: ./test.sh: work\_dri: parameter not set

```で、Bash をもっと深く知ろうと思い [入門bash 第3版](http://www.amazon.co.jp/gp/product/4873112540/ref=as_li_qf_sp_asin_tl?ie=UTF8&camp=247&creative=1211&creativeASIN=4873112540&linkCode=as2&tag=ytera-22)![](https://www.assoc-amazon.jp/e/ir?t=ytera-22&l=as2&o=9&a=4873112540)（[電子版](http://www.oreilly.co.jp/books/4873112540/)）を買ってパラパラ見てたら **「4.3.1 文字列演算子の構文」**に```
${variable:?message}

```というのが載ってました。 出来ることはほぼ "set -u" と変わらないのですが、```
$ cat test.sh
#!/bin/sh
set -u
work\_dir=/tmp
rm -fr ${work\_dri:?}/\*

$ ./test.sh
./test.sh: 4: ./test.sh: work\_dri: parameter not set or null

```「not set」だけじゃなくて「or null」と表示されてますね。そして、そこを任意のメッセージにすることもできます。```
$ cat test.sh
#!/bin/sh
set -u
work\_dir=/tmp
rm -fr ${work\_dri:?"test message"}/\*

$ ./test.sh
./test.sh: 4: ./test.sh: work\_dri: test message

```