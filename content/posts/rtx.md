---
title: "asdf の代わりに rtx を使う"
date: 2023-06-07T10:25:11+09:00
draft: false
tags: ['asdf', 'rtx']
---

[nodeenv](https://github.com/nodenv/nodenv) とか [rbenv](https://github.com/rbenv/rbenv) とか [tfenv](https://github.com/tfutils/tfenv) とか XXenv がそれぞれ `.xxx-version` というファイルにそのディレクトリ配下で使用する software の version を指定するという仕様があり、それらをまとめてやってくれる [asdf](https://github.com/asdf-vm/asdf) というツールが登場し、`.tool-versions` というファイルに複数のソフトウェアのバージョンを指定できるようになりました。 (aqua はまだ使ったことがない)

`asdf` は `$HOME/.asdfrc` に `legacy_version_file = yes` と書いておくと `.tool-versions` だけではなく `.node-version` や `.terraform-version` も読んでくれるようになっています。

`asdf` は大変便利で愛用していたのですが、shell のプロンプトに kubernetes の cluster や namespace を表示するようにした上で kubectl を asdf 管理にしておくとプロンプト表示が非常に遅いという問題に悩まされました。asdf は plugin としてインストールした kubectl だったり terraform をそのバイナリと同盟の shell script が実行されるようにして、その shell script を経由して指定の version が実行されるようになっています。この影響でいちいち shell script でゴニョゴニョやるので遅かったのです。一旦は kubectl など、遅くて困っているツールでは `asdf` を使わないということで対処していましたが、golang では shell script でそれだけではない処理までやっていてそれまた困っていました。(詳しいことは忘れた)

そんな時、`brew update` してたら [rtx](https://github.com/jdxcode/rtx) というツールを見つけました。

`rtx` は作者が同じような悩みを持っていたのか `PATH` の調整 (使いたい version の実行ファイルがあるディレクトリを `PATH` の先頭の方にセットする) だけで shell script で毎回ゴニョゴニョやる必要がないので非常にサクサク動作します。

`asdf` の `legacy_version_file = yes` 相当の動作もデフォルトです。

また、`.tool-versions` などのあるディレクトリに移動した際、指定された version がインストールされていないと、インストールされていないよと教えてくれます。

```
[WARN] Tool not installed: terraform@1.5.1
```

大変便利です。ありがとうございます。
