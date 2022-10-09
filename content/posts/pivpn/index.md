---
title: 'PiVPN で外からおうちに VPN 接続する'
date: Sat, 30 Mar 2019 13:44:43 +0000
draft: false
tags: ['DietPi', 'OpenVPN', 'OpenVPN']
---

家の PC にリモートデスクトップでアクセスしたくなったので環境構築したお話。

Chrome の Remote Desktop 機能使えば簡単にできるのかと思ったけれども Android から接続した場合に Ctrl キーなどを入力する方法がなかったのでしかたなく VPN サーバーをセットアップすることにしました。サーバーとなるのは以前の記事にもした「[kano を DietPi でサーバーにした](/2018/03/kano-dietpi/)」ラズパイです。

[![](//ws-fe.amazon-adsystem.com/widgets/q?_encoding=UTF8&ASIN=B01CSFZ4JG&Format=_SL250_&ID=AsinImage&MarketPlace=JP&ServiceVersion=20070822&WS=1&tag=ytera-22&language=ja_JP)](https://www.amazon.co.jp/Raspberry-%E3%83%9C%E3%83%BC%E3%83%89%EF%BC%86%E3%82%B1%E3%83%BC%E3%82%B9%E3%82%BB%E3%83%83%E3%83%88-Physical-Computing-Lab/dp/B01CSFZ4JG/ref=as_li_ss_il?adgrpid=50836980942&hvadid=289187078079&hvdev=c&hvlocphy=1009312&hvnetw=g&hvpos=1t1&hvqmt=e&hvrand=16615727980069949895&hvtargid=kwd-334548493913&jp-ad-ap=0&keywords=%E3%83%A9%E3%82%BA%E3%83%99%E3%83%AA%E3%83%BC%E3%83%BB%E3%83%91%E3%82%A4&qid=1554030760&s=gateway&sr=8-14&linkCode=li3&tag=ytera-22&linkId=db03dd5ea9015cc3a1f29564ff2e2cb2&language=ja_JP)![](https://ir-jp.amazon-adsystem.com/e/ir?t=ytera-22&language=ja_JP&l=li3&o=9&a=B01CSFZ4JG)（ラズパイイメージ図）

DietPi に PiVPN をインストールする
------------------------

[PiVPN](http://www.pivpn.io/) (Simplest OpenVPN setup and configuration, designed for Raspberry Pi.) というものを見つけたのでこれを使います。

とは言っても、DietPi 使いこなしてないので作法を知らないのですけど...

DietPi はログインすると次のような表示となります。  
{{< figure src="dietpi-vpn-01.png" >}}

なんとなく **dietpi-software** というやつを使えば良さそうです。実行してみましょう。

{{< figure src="dietpi-software-01.png" >}}

**Search** で検索します。

{{< figure src="dietpi-software-02.png" >}}

検索ワードは **vpn** で。

{{< figure src="dietpi-software-03.png" >}}

**PiVPN** があったので選択して **Ok** で戻ります。

{{< figure src="dietpi-software-04.png" >}}

**Install** でさっき選択した **PiVPN** をインストールします。

{{< figure src="dietpi-software-05.png" >}}

インストール中にサービスが止まったりするよと注意書き

{{< figure src="dietpi-software-06.png" >}}

OpenVPN もインストールするよ。

{{< figure src="dietpi-software-07.png" >}}

サーバーだからIPアドレスを固定する必要があるよ。

{{< figure src="dietpi-software-08.png" >}}

今のアドレスで固定しちゃってよいですか？と、DHCP サーバーで予約アドレスにしてあるので Ok

{{< figure src="dietpi-software-09.png" >}}

DHCP の IP プールだから DHCP サーバー側をうまいことやっといてね。

{{< figure src="dietpi-software-10.png" >}}

OpenVPN 用のユーザー選んでね。

{{< figure src="dietpi-software-11.png" >}}

ここでは **pivpn** を選択することにしました。

{{< figure src="dietpi-software-12.png" >}}

インターネットにポートを公開するサービスだから unattended-upgrades 機能を有効にすることを推奨しますよと、でも reboot は自分でやってね。

{{< figure src="dietpi-software-13.png" >}}

unattended upgrades を有効にしますか？はい。

{{< figure src="dietpi-software-14.png" >}}

OpenVPN で使うポートを UDP にするか TCP にするかを選択する。UDP にします。

{{< figure src="dietpi-software-15.png" >}}

ポート番号はデフォルトの 1194 のままにする。

{{< figure src="dietpi-software-16.png" >}}

{{< figure src="dietpi-software-17.png" >}}

OpenVPN 2.4 からよりセキュアな認証と鍵交換をサポートしているので有効にしますか？ モバイルアプリの OepnVPN Connect はサポートしてます。はい有効にします。

{{< figure src="dietpi-software-18.png" >}}

暗号の鍵長選択。うちのラズパイは貧弱なので 256 ビットを選択。

{{< figure src="dietpi-software-19.png" >}}

クライアントが接続する先のIPアドレス or DNS 名指定。我が家は固定IPアドレスではないので DNS を選択する。

{{< figure src="dietpi-software-20.png" >}}

DNS 名指定。我が家の WiFi ルーターは [TP-Link Deco M5](https://amzn.to/2vDRBsz) なので簡単に DDNS 設定できました。

{{< figure src="dietpi-software-21.png" >}}

確認。

{{< figure src="dietpi-software-22.png" >}}

VPN クライアントに配る DNS サーバーの IP アドレスリストを指定します。有名所の Public DNS サーバーは選択肢から選べます。スクロールして見えなくなっていますが Google の 8.8.8.8 のやつも1番目にありました。VPN での接続先にあるサーバーを指定したりする場合は Custom を選択します。

{{< figure src="dietpi-software-23.png" >}}

[Quad9 (9.9.9.9)](/2017/11/quad9/) を指定してみました。

{{< figure src="dietpi-software-24.png" >}}

確認。

{{< figure src="dietpi-software-25.png" >}}

インストール完了。`pivpn add` でクライアント用プロファイル作ってね。ログは `/etc/pivpn` ディレクトリにあるよ。

{{< figure src="dietpi-software-26.png" >}}

インストール後は reboot をオススメします。reboot しますか？はい。

{{< figure src="dietpi-software-27.png" >}}

reboot します。

{{< figure src="dietpi-software-28.png" >}}

Ok で reboot するよ。

インストール完了しました。次はクライアント用プロファル作成です。

### VPN クライアント用プロファイル作成

インストール中にも表示されていたように `pivpn add` コマンドで作成できます。

```
# pivpn -h
::: Control all PiVPN specific functions!
:::
::: Usage: pivpn <command> [option]
:::
::: Commands:
:::  -a, add [nopass]     Create a client ovpn profile, optional nopass
:::  -c, clients          List any connected clients to the server
:::  -d, debug            Start a debugging session if having trouble
:::  -l, list             List all valid and revoked certificates
:::  -r, revoke           Revoke a client ovpn profile
:::  -h, help             Show this help dialog
:::  -u, uninstall        Uninstall PiVPN from your system!
```

キーペアの秘密鍵をパスフレーズで保護しない場合は `pivpn add nopass` と実行します。 実行したら `Enter a Name for the Client:` と、クライアント名の入力を求められるので入力したら `/home/pivpn/ovpns` ディレクトリに `クライアント名.ovpn` ファイルが作成されます。このファイルをメールなどでスマホ (スマホじゃなくても良いけど) に送って [OpenVPN Connect アプリ](https://play.google.com/store/apps/details?id=net.openvpn.openvpn)を起動して読み込めば完了です。

あ、ポート転送忘れてた。

### ルーターでのポート転送

我が家は Softbank のルーターの下にさらに WiFi ルーターの [TP-Link Deco M5](https://amzn.to/2vDRBsz) が NAT しているのでそれぞれで 1194/udp を転送しました。

```
[Softbank Router] --> [Deco M5] --> [OpenVPN on DietPi]
```

これで [Microsoft Remote Desktop アプリ](https://play.google.com/store/apps/details?id=com.microsoft.rdc.android)を使えば Ctrl キーとかも使えます。やったネ！([Beta版](https://play.google.com/store/apps/details?id=com.microsoft.rdc.android.beta)もある)
