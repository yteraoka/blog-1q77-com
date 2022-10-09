---
title: 'Java がんばれ'
date: Wed, 23 Apr 2014 15:02:36 +0000
draft: false
tags: ['Java', 'java']
---

GC まわりのチューニングが難しいということで [JVM Operation Casual Talks](http://atnd.org/events/48999) などでも運用担当者からの評判がよろしくない Java ですが、遠い昔のように遅くない、むしろ速い実行環境ですよね。 Java のコードが書ける運用担当は数が少ない（私もまったく書けない）というのも理由かなとは思いますが、最近のトレンドである構成管理とかイミュータブル、Blue Green Deployment などの面では Java ってとても良いと思うのですよね。 war にしてしまえば、単にそれを置き換えれば deploy できるし、サーバーまで組み込んであれば jar を直接実行するだけかもしれません。JDK も入れ替えて再起動するだけだし、はぁ、Java ってこういうところ楽だわぁと複雑な構成のくそめんどくさい Ansible Playbook を書いた後に思ったのでした。 Java 8 でさらに便利になったみたいだし Java がんばれ！！ でも Applet はイカンですよ。PRIMERGY の管理ツール何とかしてください F 社さん。 あ、あとコマンドラインツールが Java ってのもいただけない。昔々の AWS のツールとか [OpenDJ](http://forgerock.com/products/open-identity-stack/opendj/) （おや？サイトデザイン変わってる。新しいバージョン試さなきゃ） のコマンドとか、毎度起動に時間がかかりすぎます。 p.s. maven わけわかんないし、XML もキライです