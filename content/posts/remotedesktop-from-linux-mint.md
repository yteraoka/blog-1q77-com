---
title: 'Linux Mint から Windows へのリモートデスクトップ'
date: Sun, 16 Dec 2012 15:25:38 +0000
draft: false
tags: ['Linux', 'Linux Mint']
---

Linux Mint 14.1 から Windows へ RemoteDesktop 接続するのには [Remmina](http://remmina.sourceforge.net/) を使うのかなと思って試してみたが、キーマップが合わなかったので設定を見てみて RDP 欄の「クライアントのキーボードマッピングを使用する」にチェックを入れたら CapsLock を Ctrl に入れ替えてるのも反映されたけど、「| (縦棒)」だけが入力できなかった... これでは pipe での処理 (`ps -ef | grep xxx` とか) が出来なくて致命的なので馴染みの [rdesktop](http://www.rdesktop.org/) をインストールした。

```
rdesktop -f -a 16 -k ja -z -u {ユーザー名} -d {ADドメイン} {接続先ホスト}
```

`-k` でキーマップを指定している。使えるマップは `/usr/share/rdesktop/keymaps/` にあるもの。

[Ubuntu 12.04のリモートデスクトップ・クライアントはRemminaに変更 - 情報技術の四方山話](http://blog.goo.ne.jp/takuminews/e/52ce0edbbb71b72e9cd0108cf2e2bddb)
