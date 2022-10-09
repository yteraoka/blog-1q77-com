---
title: '在宅ワークでの会議中に家族へメッセージを伝える'
date: Fri, 01 May 2020 16:11:19 +0000
draft: false
tags: ['未分類']
---

もうずっと家にいるのが辛い今日この頃ですが、家で仕事をしていて会議中に家族から「ごはんだよ」とか声を掛けられても返事が出来ないよってことがありますよね。そんな時に Google Home （今は Google Nest って呼ぶのかな？） を使って伝えることを思いついたのでやってみます。

「[Google Home に任意のメッセージを喋らせる](/2019/10/google-home-mini-and-text-to-speech/)」という記事を過去に書きました。やることは同じです。[go-chromecast](https://github.com/vishen/go-chromecast) 日本語使えるようにする patch とかを merge してもらったので `--language-code ja-JP` でいけますよ。

使い方は以前の投稿時と同じです。返事をしたい時にさっと実行できるように cast という名前の wrapper スクリプト (bash) を用意しました。

```
$ cast 今会議中

```

```
$ cast 5分で行く 
```

なんて出来ます。が、落とし穴が...

VPN です。VPN 使わなきゃアクセス出来ないものがあって使ってるんですが、そうすると mDNS でデバイスを見つけられないんです 😭 （VPN の設定などにも依存するかもしれません、go-chromecast はインターフェースを指定する機能もあってローカルの NIC を指定してもダメでした）

しかし、諦めるのはまだ早い。go-chromecast は IP address と port を指定して直接 Device にアクセスできます。この情報は前もって `go-chromecast ls` コマンドで確認しておくことができます。でもきっと DHCP なんで変更があると面倒だから DHCP サーバー （ルーターや WiFi AP） で IP アドレスを固定してしまっても良いでしょう。

それでは良い在宅ワークを。

今 (2020-05-02) は [Google Nest Mini が2,000円 OFF で買える](https://store.google.com/jp/config/google_nest_mini)みたいですね。赤いやつしか残ってないっぽい。天気予報とキッチンタイマー以外の使い道があるのかどうかわかりませんけど...
