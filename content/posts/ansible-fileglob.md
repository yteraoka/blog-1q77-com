---
title: 'ansible の copy でファイルを glob 指定する'
date: Wed, 06 Nov 2013 05:13:19 +0000
draft: false
tags: ['Advent Calendar', 'Ansible']
---

この投稿は [Ansible Advent Calendar 2013](http://qiita.com/advent-calendar/2013/ansible) の5日目の記事です。 [前日はこちら](http://qiita.com/yamasaki-masahide/items/fa96225815869daa9e53) こんにちは、[Ansible Tutorial](http://yteraoka.github.io/ansible-tutorial/) をそろそろリニューアルしないといけないなと思いつつ、更新すら全然できていない [yteraoka](http://qiita.com/yteraoka) です。あの Playbook は 1.2 時代に書いて 1.3 でも 1.4 でもテストしてないので動かないかもしれない... WordPress だってバージョンの指定がもう古いし。 このブログの前回のポスト「[ansible の copy/template で例外対応](/2013/11/ansible-with-first-found/)」で次は fileglob を試してみると書いたので、今日はそれをやってみます。 が、その前に... 前回、with\_first\_found を試して copy モジュールは期待通りに動作したのに template はちょっと期待と違う動作となりました。なんでかなぁ？とコードをチラ見してたところこんな発見がありました。

{{< twitter user="yteraoka" id="405674038741057536" >}}

> with\_first\_found と似て非なる first\_available\_file というものがあったのか [#ansible](https://twitter.com/search?q=%23ansible&src=hash)
> 
> — yteraoka (@yteraoka) [2013, 11月 27](https://twitter.com/yteraoka/statuses/405674038741057536)

first\_available\_file を使うと、期待通りに role の templates ディレクトリの中を順番に探してくれました。 ヤッタネ！ では今日の本題 [fileglob](https://github.com/ansible/ansible/blob/devel/lib/ansible/runner/lookup_plugins/fileglob.py) を使ったファイルのコピーです。『えっ！そんなの copy モジュールでディレクトリ毎コピーすればいいじゃん！』っていう Ansible マスターなお方はちょいとお待ちを。 copy モジュールの再帰コピーは 1.4 からの新機能 [Ansible 1.4 Released!](http://blog.ansibleworks.com/2013/11/21/ansible-1-4-released/) なんです。私、まだ 1.3 ユーザーなのです。 EPEL さんなかなか 1.4 にならないので只今 Python コンパイル中でござる。 では順番に。 テキトーにファイルを準備

```
$ ls roles/test/files/conf.d
aaa  bbb  ccc  ddd.conf  eee.conf
```

files ディレクトリの conf.d/\*.conf を対象にしてみる。 debug モジュール便利ですね。

```
$ cat roles/test/tasks/fileglob.yml 
---
- debug: msg={{ item }}
  with_fileglob: conf.d/*.conf
  tags: test
```

実行

```
$ ansible-playbook -i hosts site.yml -l ansibletest1 -t test -v

PLAY [ansibletest1] *********************************************************** 

GATHERING FACTS *************************************************************** 
ok: [ansibletest1]

TASK: [debug msg=] ************************************************************ 
ok: [ansibletest1] => (item=/home/ytera/ansible/roles/test/files/conf.d/ddd.conf) => {"item": "/home/ytera/ansible/roles/test/files/conf.d/ddd.conf", "msg": "/home/ytera/ansible/roles/test/files/conf.d/ddd.conf"}
ok: [ansibletest1] => (item=/home/ytera/ansible/roles/test/files/conf.d/eee.conf) => {"item": "/home/ytera/ansible/roles/test/files/conf.d/eee.conf", "msg": "/home/ytera/ansible/roles/test/files/conf.d/eee.conf"}

PLAY RECAP ******************************************************************** 
ansibletest1               : ok=2    changed=0    unreachable=0    failed=0
```

期待通りに動作しそうです。

conf.d/\* とかまるっとコピーしたいなんて用途ありますよね。

rsync とか tar で展開とかだと変更がないのに changed になって、不要な notify が実行されたりするかもしれませんからね。

さて、1.4 からの再帰コピーですが、rsync ライクな実装になっていて、 src のディレクトリ指定で最後に '/' をつけておくと、そのディレクトリの中身だけをコピーし、 '/' を付けなかった場合はそのディレクトリごとコピーされるんです。どんどん便利になって素敵ですね。私もちょっぴり貢献をば [https://github.com/ansible/ansible/pull/4027](https://github.com/ansible/ansible/pull/4027) それでは明日は [takuan\_osho](http://qiita.com/takuan_osho) さんの記事をお楽しみに〜。
