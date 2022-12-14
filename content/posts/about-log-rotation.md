---
title: 'log rotation まわりの話'
date: Mon, 04 Feb 2013 00:45:10 +0000
draft: false
tags: ['Linux', 'log']
---

[logrotateがプロセスにHUP送る理由を調べてみた - カイワレの大冒険](http://d.hatena.ne.jp/masudaK/20110914/1315999265) へのコメントです。

* * *

> *   HUPは設定ファイルを読み直すというような単純なものじゃない

rsyslog についての話かな、だとすると最新の rsyslog は SIGHUP では設定を読み直さないらしい。だからログファイルを開き直すだけかな。rsyslog や syslog-ng なら設定次第で書きだすファイル名に日付を入れられたりするけど。rsyslog に限定しない話だと、signal を受けた時の処理は SIGKILL 以外は自由に書けます。通常、Ctrl-C で SIGINT が送られ、process は中断されますが中断で不整合が起きないように綺麗に終了させたりします。

* * *

> *   プロセスが生きている限りは、開いたままのファイルをmvしたりしても、それはmvした先に書かれる。要はファイル名なんて関係ない

ファイルシステムが違うところ(別パーティション)へ mv してしまうと、それは mv 先には書かれないので注意。開いた時の inode に書き続けるということですね。誤って削除してしまったファイルもどれかの process が開いていたら /proc/{PID}/fd/ の中から読み出せます。

* * *

> *   ログローテートが走ったときにsyslogとかrsyslogにHUP送るけど、これはプロセスを殺さず、ログファイルのinodeを更新するため。
> *   inode更新されるので、ファイルを読みなおしたのと同じ挙動となる

なんか表現に違和感がありますね。開いていたファイルを mv (rename) してなかったら同じ inode のファイルに追記しますよ。ファイルを読み直す？

* * *

> そのうち、open(2)させたのちに無限ループさせたあたりの挙動追ってみると面白いのかもなぁと思ったり、誰か書いてくれると期待したり。

これはどういうことだろう？

* * *

**ここからは追加の話** SIGHUP でログファイルを開き直してくれないプログラムの場合は logrotate で copytruncate を指定する必要があります。これはそれまでのファイルの中身を別ファイルにコピーした後に、ファイルサイズを0にします、inode は変えられません。でもログファイルが大きいとこれはかなりの負荷がかかります。rename だと負荷はほとんどないのに。そんな場合は pipe で cronolog とか rotatelogs をかましてあげるのが良いです。copytruncate でハマるのはログファイルが追記モードで開かれていない場合、java の "-Xloggc" とか。truncate 後も元のファイルの位置から書き続けます... truncate ついでに書いておくと vi での編集・上書きや cp コマンドでの上書きは truncate して書きなおすので誰かが読込中だったりすると思わぬエラーが発生するかもしれません。shell script は読みながら順番に実行するため影響を受けやすいです。これを回避するためにはコピーして新しいファイルを編集した後に mv で戻すなどの対応が必要です。rsync コマンドは一時ファイルを作ってそれを rename してくれます。svn update もそうですね。 昔、symantec の virus 定義ファイルのダウンロード元が truncate して上書きしていたみたいでしょっちゅう中途半端なファイルをダウンロードさせられてました。