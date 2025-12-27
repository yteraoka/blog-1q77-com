---
title: 'wine を使って Linux で LINE アプリを使う'
date: Sat, 06 Sep 2014 05:21:49 +0000
draft: false
tags: ['LINE', 'Linux', 'Linux Mint', 'WINE']
---

昔は LINE にも Web 版ってのがあったらしいのですが、いまはもう無くって、PC 用には Windows のアプリしかありません。でも私の PC は Linux (Linux Mint 17 Qiana) なのです。 前にも wine で動かそうとしたことがあるのですがその時はうまく動作しませんでした。でもまた試してみようとやってみたら動きました。 ググると wine 1.6 ではダメだけど 1.7 では動いたとあったので 1.7 を ubuntu にインストールする方法を調べて [http://ubuntuhandbook.org/index.php/2014/06/install-wine-1-7-20-ubuntu-linux/](http://ubuntuhandbook.org/index.php/2014/06/install-wine-1-7-20-ubuntu-linux/) を参考に

```
$ sudo add-apt-repository ppa:ubuntu-wine/ppa
$ sudo apt-get update
$ sudo apt-get install wine1.7
```

これで wine 1.7 はインストールできました。でも LINE のインストーラを実行したら mono と gecko が無い、wine でインストールもできるけど distribution の package を使ったほうが良いよと表示されるので

```
$ sudo apt-get install wine-mono4.5.2
$ sudo apt-get install wine-gecko2.24
```

これで一応動いてます。
