---
title: 'Ubuntu 16.04 でのシステムフォントの変更'
date: Sat, 26 Nov 2016 10:58:51 +0000
draft: false
tags: ['Linux', 'Ubuntu']
---

Chrome や Firefox、gnome-terminal の内部で表示するフォントはそれぞれのアプリの設定で可能だが、Window Title やアプリ側で設定できない部分のフォントの変更には **unity-tweak-tool** を使う

```
$ sudo apt-get update
$ sudo apt-get install unity-tweak-tool
$ unity-tweak-tool
```

Keepass で日本語表示するために Keepass 内で変更可能なフォントを変更したら 1366x768 の画面では縦がおさまらなくなってしまったため変更したかった。
