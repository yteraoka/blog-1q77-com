---
title: "editcap で tcpdump のキャプチャファイルから指定の時間帯を切り出す"
description: |
  tcpdump で一定期間のキャプチャをファイルに保存することがあるかと思いますが、その中から必要な部分だけを切り出したいことがあります。
  editcap コマンドで特定の時間を切り出してみました。
date: 2023-06-15T23:46:42+09:00
draft: false
tags: ['tcpdump']
image: cover.jpg
author: "@yteraoka"
categories:
  - IT
---

## 課題

ちょっと大きめ (時間範囲の広い) pcap ファイルがあって、wireshark で見るにしてもちょっと大きすぎるなということがありました。

見たい時間帯だけに絞ったファイルにできないかなと思い調べたメモです。

## editcap

Wireshak とともにインストールされている [editcap](https://www.wireshark.org/docs/man-pages/editcap.html) というコマンドで実現可能なことがわかりました。

`big.pcap` というファイルがあったとします。ここから指定した時間範囲のデータだけを切り出して `small.pcap` というファイルに保存するには次の様にします。マニュアルの表記では `-A` が start time で `-B` が stop time となっています。grep コマンドみたいに **A**fter と **B**efore で覚えても良いかもしれません。

```bash
editcap -F libpcap \
  -A "2023-06-15 09:00:00" \
  -B "2023-06-15 09:05:00" \
  big.pcap small.pcap
```

時刻は `YYYY-MM-DD HH:MM:SS[.nnnnnnnnn][Z|±hh:mm]` か `YYYY-MM-DDTHH:MM:SS[.nnnnnnnnn][Z|±hh:mm]` で指定します。
timezone (offset) を省略した場合は localtime として扱われます。

### 時間以外での抽出

時間帯を絞りたいのではなく、ip address や port など tcpdump の filter で絞りたい場合は tcpdump コマンドを使い、`-r` で読み込んで `-w` で書き出せばフィルタリングされた結果を別ファイルとして書き出すことが可能です。

## brim

ちなみに、ずいぶん前に紹介した [brim](/2020/12/brim-introduction/) では特定の tcp stream を簡単に pcap ファイルとして保存できてました。
