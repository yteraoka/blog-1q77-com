---
title: 'fluent-plugin-tail-asis できた'
date: Tue, 05 Feb 2013 16:05:29 +0000
draft: false
tags: ['fluentd', 'Ruby']
---

Ruby 素人が作ってみました。 [https://github.com/yteraoka/fluent-plugin-tail-asis](https://github.com/yteraoka/fluent-plugin-tail-asis) rubygems にも UP したった。

* [fluent-agent-lite と in\_tail](/2013/01/fluent-agent-lite-and-in_tail/)
* [in\_tail\_asis というのを書いた](/2013/02/in_tail_asis/)

あたりでやってたやつ。 ネーミングルールとか良くわからないけどまぁとりあえず動きましたよと。

```
fluent-gem install fluent-plugin-tail-asis
```

で

```
  type tail_asis
  asis_key message
  path /path/to/input_log_file
  pos_file /var/run/input_log_file.pos
  tag asis.test  
```

と指定して fluent-plugin-file-alternative に渡してやればそのままログの収集ができます。 正規表現を使わない分、素の tail より軽いはずじゃないかなと。
