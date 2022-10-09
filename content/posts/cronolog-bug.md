---
title: 'EPEL の cronolog バグってた'
date: Tue, 21 May 2013 13:35:43 +0000
draft: false
tags: ['Linux', 'log']
---

cronolog は時間ベースの便利なログローテーションツールですが、オリジナルのサイト [http://cronolog.org/](http://cronolog.org/) は随分昔から更新されておらず、バグも [PATCH](http://cronolog.org/patches/index.html) へのリンクがあるだけで修正されていません。そのため、自前で patch を当てて使っていました。 が、最近「あれ？[EPEL](https://fedoraproject.org/wiki/EPEL/ja)にパッケージがあるじゃん！！いまさら patch が当たってないなんてことは無いだろう。これ使えばいいや」と調べもせずに使い始めてました。そしたら「あれ？やっぱバグってね？」と気付き、[SRPM](http://dl.fedoraproject.org/pub/epel/6/SRPMS/cronolog-1.6.2-10.el6.src.rpm) を取ってきて調べてみたら largefile 対応の patch しか当たってませんでした。もうひとつ symbolic link がズレて直らない問題があるのにぃぃ。 この [patch](https://gist.github.com/yteraoka/5619060) どうやって EPEL に入れてもらえばいいんだべか？ まぁ、ログのローテーションができないわけじゃなくて最新のログファイルや一つ前のログファイルへの Symbolic link が更新されないし、しばらくログが出ないなんてことが無い場合には発生しない。