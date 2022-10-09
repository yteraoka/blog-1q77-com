---
title: 'Ubuntu 18.04 で xkb を使ってキーマップをカスタマイズする'
date: Thu, 17 Oct 2019 15:54:33 +0000
draft: false
tags: ['Ubuntu', 'keyboard']
---

Laptop でしばらく Windows 10 を使っていたのですが、WSL2 を使おうと思っていじってたらいつまで経ってもシャットダウンが完了せず、毎回強制的に電源を切らなければならない不自由なことになってしまい、もう嫌になったのでまた Linux にもどしました。で、私の Laptop はもうガタが来ており、右矢印キーが壊れていて反応しません。でもたまに使うことがあるので、その上に位置する右シフトキーに右矢印キーとして機能してもらうことにします。Windows では [ChangeKey](https://forest.watch.impress.co.jp/library/software/changekey/) というフリーソフトで対応してました。

CapsLock と Ctrl キーを入れ替えるのは簡単にできるようになっているのですが、細かなカスタマイズは自分で頑張る必要があるみたいです。幸い先人が方法を公開してくれてるのでググるだけですけど。

今回は「[Ubuntu 16.04 で XKB を使ってキーマップをカスタマイズする](https://qiita.com/uchan_nos/items/a2485b51f5f3fb0db8f8)」を参考にさせていただきました。

```
$ mkdir -p .xkb/{keymap,symbols}
$ setxkbmap -print > ~/.xkb/keymap/mykbd
$ cat > ~/.xkb/symbols/custom <<\_EOF\_
xkb\_symbols "myright" {
  replace key <RTSH> { \[ Right \] };
};
\_EOF\_

```として、こんな感じのファイルを作ります。```
$ tree .xkb
.xkb
├── keymap
│   └── mykbd
└── symbols
    └── custom

2 directories, 2 files

```なんだか Qiita の記事のコピーみたいになってきたが将来の私のためにメモっておく```
$ mkdir ~/bin
$ cat > ~/bin/load\_xkbmap.sh <<\_EOF\_
#!/bin/bash

if \[ -s $HOME/.xkb/keymap/mykbd \] ; then
  sleep 1
  xkbcomp -I$HOME/.xkb $HOME/.xkb/keymap/mykbd $DISPLAY 2> /dev/null
fi
\_EOF\_
$ chmod +x ~/bin/load\_xkbmap.sh

```

でもって、`gnome-session-properties` を起動して Startup Programs に登録しておきます。

以上