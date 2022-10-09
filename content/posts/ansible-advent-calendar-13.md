---
title: 'Ansible 最近の発見'
date: Fri, 13 Dec 2013 14:57:35 +0000
draft: false
tags: ['Advent Calendar', 'Ansible', 'ansible']
---

この投稿は [Ansible Advent Calendar 2013](http://qiita.com/advent-calendar/2013/ansible) の13日目の記事です。 [前日はこちら](http://qiita.com/ando-masaki/items/b2780c70e521b296d85a) 2打席目です。 息子二人が連続で胃腸炎にかかりゲロとの戦いを強いられていて書こうと思っていたネタの準備ができなかったので、モジュール一覧ページを見て、「おーっ、こんな機能あったんだぁ！」って思ったものを書いてみます。

### fetch モジュールの validate\_md5

```
validate\_md5={yes|no}

```というパラメータが 1.4 で追加されていました。fetch 元と fetch してきたファイルの md5sum を比較して正しくコピーできたことを確認できます。 しかし copy モジュールにはこの機能ないんですね。 代わりにといっては何ですが、 copy と template モジュールには```
validate=任意のコマンド

```というパラメータがあります。 `%s` というマクロが使えて、作成した一時ファイル（rename前）の path に置換されて実行されます。例えば Apache のコンフィグファイルであれば```
validate="/usr/sbin/httpd -t -f %s"

```とすることで syntax check に失敗したら rename 前にエラーで終了させることができます。起動しない設定ファイルを反映してしまうことを防げます（もちろん syntax check では見つけられないミスもありますが）。 おっと、1.4 で lineinfile モジュールにもこの機能が追加されていました。

### unarchive モジュール

1.4 で新規に追加されたモジュールです。 command モジュールで `tar xf ... chdir=/some/where` 使えば tar.gz でも tar.bz2 でも tar.xz も自動判別して展開はしてくれますが、このモジュールを使うと `tar` の `--diff` 機能で差分が見つかった場合のみ実際に展開されます。これはちょっと便利。changed かどうかは重要ですからね。 zip ファイルの場合は常に展開されるようです。

### file モジュールの state=touch

これまでは `file`, `directory`, `link`, `hard`, `absent` だけでしたが、`touch` が 1.4 で追加されていました。 Passenger アプリの deploy 時に tmp/restart.txt の timestamp を更新することでアプリだけリロードさせることができますが、こんな場合に使えますね。 もちろん `command: touch /some/where/tmp/restart.txt` でできるんですけど。

### postgresql\_privs

思ってたより便利そう。 ヤバい時間がない...

### postgresql\_user

1.4 からパスワードが必須ではなくなってました。LDAP 認証時にはパスワード設定する必要ないから助かる。 [頓挫した技術系アドベントカレンダーの一覧(2013年)](http://dic.nicovideo.jp/a/%E9%A0%93%E6%8C%AB%E3%81%97%E3%81%9F%E6%8A%80%E8%A1%93%E7%B3%BB%E3%82%A2%E3%83%89%E3%83%99%E3%83%B3%E3%83%88%E3%82%AB%E3%83%AC%E3%83%B3%E3%83%80%E3%83%BC%E3%81%AE%E4%B8%80%E8%A6%A7(2013%E5%B9%B4)) に乗ってしまうと困るから今日はこれで終了。 3打席目やります。 明日は私の誕生日です（さらにおじさんに...） じゃなくって、明日は [@r\_rudi](https://twitter.com/r_rudi) さんの2打席目です。