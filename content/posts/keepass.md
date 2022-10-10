---
title: 'KeePassでパスワード管理'
date: Sun, 27 Jul 2014 14:46:29 +0000
draft: false
tags: ['keepass', 'password', 'security']
---

[KeePass](http://keepass.info/) でブラウザへのID、パスワード入力を管理しましょう。

Windows
-------

KeePass 本体のインストール方法は省略 ブラウザとの連携は WebAutoType プラグインでできます。この方法だと IE でも Firefox でも Chrome でもこれだけで同じように使えます。ブラウザ側にプラグインは不要です。 [http://keepass.info/plugins.html#webautotype](http://keepass.info/plugins.html#webautotype) [http://sourceforge.net/p/keepass/discussion/329220/thread/ecff27ab/](http://sourceforge.net/p/keepass/discussion/329220/thread/ecff27ab/) インストールは [http://sourceforge.net/projects/webautotype/files/latest/download](http://sourceforge.net/projects/webautotype/files/latest/download) ここから zip ファイルをダウンロードして、KeePass フォルダに WebAutoType.plgx をコピーする。 KeePass を起動する。 これだけで OK 後は、KeePass の URL 欄をちゃんと埋めておいてそれにマッチするサイトに アクセスし、ログフィンフォームのユーザーID欄にカーソルがある状態で

```
Ctrl + Alt + A
```

をタイプすると勝手に入力してくれます。 入力シーケンスはデフォルトでは次のようになっていますが KeePass のそれぞれのエントリでカスタマイズ可能です。

```
{USERNAME}{TAB}{PASSWORD}{ENTER}
```

マッチするアカウントが複数あったら選択ウインドウが表示されます。 OpenSource です。 [http://sourceforge.net/p/webautotype/code/HEAD/tree/](http://sourceforge.net/p/webautotype/code/HEAD/tree/) WebAutoType の弱点は Basic 認証には対応しないところです。Linux 編で紹介する KeePassHttp は Basic 認証にも対応しているので、ブラウザごとにプラグインを入れるのが気にならなければそちらが良いかも。

Linux (ubuntu / mint)
---------------------

Linux では WebAutoType は使えないので [KeePassHttp](https://github.com/pfn/keepasshttp) を使います。 [How to Integrate KeePass With Chrome and Firefox in Ubuntu](http://www.maketecheasier.com/integrate-keepass-with-browser-in-ubuntu/) に書いてあります。 私は Linux Mint ですが、ubuntu ベースなので同じです。 [https://github.com/pfn/keepasshttp](https://github.com/pfn/keepasshttp)

```
$ sudo apt-get install keepass2 mono-complete
```

[KeePassHttp](https://github.com/pfn/keepasshttp) から KeePassHttp.plgx を Download し、/usr/lib/keepass2/plugins/ ディレクトリに置きます。このディレクトリが存在しない場合は作成します。その後 keepass を起動します。 ブラウザそれぞれにもプラグインをインストールします。Firefox には [PassIFox](https://addons.mozilla.org/en-us/firefox/addon/passifox/) を、Google Chrome には [chromeIPass](https://chrome.google.com/webstore/detail/chromeipass/ompiailgknfdndiefoaoiligalphfdae) をインストールします。 後は KeePass のエントリに URL を設定しておけばブラウザでマッチする URL にアクセスしたら何も入力しなくても自動でフォームに入力された状態になります。アクセス許可の確認が出たりはしますが。

Mac
---

持ってないから知らない。Keychain でできるんですかね？
