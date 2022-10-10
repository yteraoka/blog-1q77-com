---
title: 'いまさら cpanm'
date: Mon, 07 Jan 2013 11:37:34 +0000
draft: false
tags: ['Linux', 'Perl']
---

もともと Perl メインでプログラミングしてたのですが、CPAN が肥大化(ただメール送るためだけに Email::Sender::Simple を入れようとしたらすげー依存で大量の CPAN モジュールがインストールされて Enter 打つだけで疲れた、あと yum で入る奴とそうでないのが混ざって気持ち悪い)してたのでなんか面倒で避けてたのですが、リターンメールの処理に [BounceHammer](http://bouncehammer.jp/) を使ってみようかなと思って重い腰を上げてみた。 自分でコード書くときはできるだけ依存させないように、標準モジュールでおさまるようにしてた。大したコードではないけれど。もちろん車輪の再発明もある。 [cpanm](https://github.com/miyagawa/cpanminus) すら避けていたが、Rails が [bundler](http://gembundler.com/) でかなりイケてる感じなので Perl にも似たようなのないかなと思ったら、やっぱりあるんですね [Carton](https://github.com/miyagawa/carton) !! あれ、でもα版で止まってる？？？ Carton 使ってたけど cpanm に戻したっていう blog もあったので cpanm だけで行く事に。

```
$ cpanm -l /path/to/install ModuleName
```

って超便利!! なぜ今まで試さなかったんでしょうか。 こんなに簡単にインストールできるのに

```
$ cd ~/bin
$ curl -LO http://xrl.us/cpanm
$ chmod +x cpanm
```

あと、これ

```
$ export PERL5OPT=-I$HOME/perl5/lib/perl5
```

[404 Blog Not Found:perl - の@INCを実行寸前に変更する](http://blog.livedoor.jp/dankogai/archives/51831215.html) @miyagawa さんありがとう!!
