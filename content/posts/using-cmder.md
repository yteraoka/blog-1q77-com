---
title: 'Cmder で Windows 生活を快適に？？'
date: Wed, 22 Nov 2017 15:47:57 +0000
draft: false
tags: ['Windows']
---

ずっと Linux mint や Ubuntu で使ってたノート PC の OS を Ubuntu 17.10 にしたらフリーズして強制電源 Off 後に Operating System Not Found となる現象が短期間に2度も発生したので気分転換に Windows 10 にしてみた。

せっかくなので快適に使いたいなと cmd.exe に代わるものがないかとググってみたら [Cmder](http://cmder.net/) ([github](https://github.com/cmderdev/cmder)) が良いらしいということで入れてみました。

インストールは [Chocolatey](https://chocolatey.org/packages/Cmder) で行いました。

`"C:\tools\cmder\Cmder.exe"` にインストールされました。 `C:\tools\cmder\vendor\clink` にインストールされる [clink](https://github.com/mridgers/clink) のおかけで bash に近い感じで使えます(Ctrl-A, Ctrl-E, Ctrl-U, Ctrl-N, Ctrl-P, Ctrl-R,...)。

快適！！タブ機能もある。
さらに、`C:\tools\cmder\vendor\git-for-windows` に coreutils とか findutils に入ってる各種コマンドが入ってて Linux 的に使えるんです（しかし、今の環境では別途インストールしている Docker Tools for Windows によって `C:\Program Files\Git` にも Git for Windows が入っており、こちらが使われてるっぽい）。

Perl まで入ってる。 bash も入ってるけど私の場合は Windows Subsystem for Linux を先に入れていたからか bash と打つとそのまま WSL の Ubuntu に入ってしまいます。直接 git-for-windows 内の bash を指定すればそっちの bash も起動しますが。 [git-for-windows](https://git-for-windows.github.io/) なのでもちろん git も普通に使えます。vim も gawk も find も xargs もある。

```
ipconfig /all | iconv -f sjis -t utf-8 | less
```

なんてこともできる。 ssh も入ってるので vagrant を別途入れておけば vagrant ssh もできますし、普通に ssh でサーバーにログインできます。Putty 要らず。 素晴らしい。

Windows Subsystem for Linux でどれほど快適になってるのかも試してみたかったわけですが、Cmder と Vagrant があればそれで良いかも。Docker も手軽に使いたいところだがこれはシームレスにはいかないようだ。Windows 10 Home Edition だから Docker toolbox なんだけど Docker for Windows だとた違うんだろうか？ ・・・

使ってたらやっぱり不満は出てきた...

Ctrl-V との組み合わせでコントロールコード入れたくてもクリップボードからのペーストが機能しちゃって困る そして、結局 Git for Windows についてくる git-bash.exe を使うことにした。

そんなわけで Cmder とはお別れです。あんいんすとーーる
