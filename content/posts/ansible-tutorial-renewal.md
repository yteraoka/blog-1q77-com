---
title: 'Ansible Tutorial リニューアルしました'
date: Sun, 22 Dec 2013 15:22:09 +0000
draft: false
tags: ['Advent Calendar', 'Ansible']
---

この投稿は [Ansible Advent Calendar 2013](http://qiita.com/advent-calendar/2013/ansible) の23日目の記事です。 22日目: [Ansibleを導入したい人の為のくどきポイント](http://qiita.com/ryurock/items/9cd0aee66003eba482e4) 前回の Advent Calendar ポストの翌日が3736回目の誕生日だったのですが、胃腸炎でゲロゲロしながら過ごした @yteraoka です。息子もゲロゲロしてて、ゲロゲロがゲロゲロを介護するという老老介護ならぬゲロゲロ介護でした。素晴らしい誕生日ですね。。。 最近の Ansible の話題と言えば [ANSIBLEWORKS GALAXY](https://galaxy.ansibleworks.com/) ですが、こっちは明日、明後日できっと誰か書いてくれますよね。Ansible 開発者の書いた Playbook とか参考になりますね。へ〜、はぁ〜って見てました。っていうほどまだ見れてないけど今後、どんどん参考にしていきたい。 今日の話題は [Ansible Tutorial](http://yteraoka.github.io/ansible-tutorial/) をリニューアルしましたよという告知。まぁ、内容的にはほとんど変わってないわけですけど... ググると上位に出てくるので Ansible の変化にもついていかないとなという事で。 一応変更点を上げると

*   1.4 でテストした
*   かつて `{{ foo }}` が使えなかったモジュールで `${ foo }` としていたところを `{{ foo }}` が使えるようになったので変更。`${ fooo }` は廃止予定のようです。
*   WordPress の Secret Key 設定に https://api.wordpress.org/secret-key/1.1/salt/ を使って register, stdout を活用 (php で require した方が良かった？)
*   [Ansible in detail](http://yteraoka.github.io/ansible-tutorial/ansible-in-detail.html) は全然更新できなかったので [Wiki](https://github.com/yteraoka/ansible-tutorial/wiki/Ansible-Note) に変更
*   その Wiki に [failed\_when](https://github.com/yteraoka/ansible-tutorial/wiki/failed-when), [changed\_when](https://github.com/yteraoka/ansible-tutorial/wiki/changed-when) を追加。この機能便利です。
*   あと typo の修正とか細かい所は忘れました

もっと書きたいことはあったりしますが Wiki に追加して行こうと思います。 まだ、入門には使えるんじゃないかなと我ながら思ってます。Ansible 使ってみようかなって思ってる人は試してみてください。ではでは〜 明日は [@r\_rudi](https://x.com/r_rudi) さんです。
