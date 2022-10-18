---
title: 'in_tail_asis というのを書いた'
date: Sat, 02 Feb 2013 11:08:36 +0000
draft: false
tags: ['fluentd', 'ruby']
---

先日、「[fluent-agent-lite と in\_tail](/2013/01/fluent-agent-lite-と-in_tail/)」というエントリーで fluentd 本体への patch を書いて Pull Request までしたと書いたのだが、Ruby 全然わかんないし、数行足すだけだからそれが楽でそうしたのだが、plugin でも簡単に書けそうだと気づいたので別ファイルとして書いてみた。in\_tail.rb と同じディレクトリに置いたら動いたけど正しくはどうすれば良いのだろうか？テストの書き方とか gem にする方法は...先は長いな。
