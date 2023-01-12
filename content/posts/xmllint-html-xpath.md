---
title: "xmllint で HTML 内の任意の値を取り出す"
date: 2023-01-12T23:40:51+09:00
draft: false
tags: ["shell", "HTML"]
---

サクッと shell script で HTML の中の何かを取り出したい時があります。
そんな時に使えるのが xmllint.
しっかりやるなら python の Beautiful Soup を使ったりしますが、本当に簡単なことを簡単にやりたい場合に xmllint でサクッとやったメモ。

試した環境は次の通り。

```
$ sw_vers
ProductName:            macOS
ProductVersion:         13.1
BuildVersion:           22C65
```

```
$ /usr/bin/xmllint --version
/usr/bin/xmllint: using libxml version 20913
   compiled with: Threads Tree Output Push Reader Patterns Writer SAXv1 FTP HTTP DTDValid HTML Legacy C14N Catalog XPath XPointer XInclude ICU ISO8859X Unicode Regexps Automata Schemas Schematron Modules Debug Zlib
```

FORM の HTML が返ってくるのでそこから hidden で埋め込まれている input の value や送信先 (action) を取り出したかった。

次のような HTML (example.html) があったとする

```html
<html lang="ja">
  <head>
    <meta charset="utf-8">
    <title>タイトル</title>
  </head>
  <body>
    <form method="post" id="myform" action="https://httpbin.org/anything">
    <input type="hidden" name="item1" value="apple">
    <input type="hidden" name="item2" value="banana">
    <button type="submit">submit</button>
    </form>
  </body>
</html>
```

**item1** の **value** を取得したい場合にどうするか

```bash
$ xmllint --html --xpath "string(//input[@name='item1']/@value)" example.html
apple
```

value の中身の `apple` が取得きた。

`string()` で囲まなかった場合は `value="apple"` となる。

```bash
$ xmllint --html --xpath "//input[@name='item1']/@value" example.html
 value="apple"
```

さらに `@value` も外すとこんな感じ。

```bash
$ xmllint --html --xpath "//input[@name='item1']" example.html
<input type="hidden" name="item1" value="apple"/>
```

では title の値 (`<title>` と `</title>` で囲まれた中身) が欲しい場合はどうするか。
`text()` を指定する。

```bash
$ xmllint --html --xpath "//title/text()" example.html
タイトル
```

`text()` を付けずに次の様にすると `<title>myform</title>` が出力される。


```bash
$ xmllint --html --xpath "//title" example.html
<title>タイトル</title>
```

あ、そうそう、form の action は次のようにする。

```bash
$ xmllint --html --xpath "string(//form[@id='myform']/@action)" example.html
https://httpbin.org/anything
```
