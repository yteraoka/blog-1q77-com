---
title: 'VPN 接続時に PC を起こしてやる'
date: Mon, 01 Apr 2019 15:19:13 +0000
draft: false
tags: ['OpenVPN']
---

[前回の設定](/2019/03/pivpn/)で外出先からスマホでおうちに VPN 接続してリモートデスクトップで PC にアクセスできるようになりました。しかし、まだ問題が残っていました。PC は未使用時にはスリープ状態になっているのでした。でもおじさんなので知っています、こんな時のために Wake-on-LAN という機能があるのです。ラズパイサーバーからマジックパケットを送ってあげましょう。（私は root としてログインしてたので以下はその前提になっています。必要であれば sudo とかを足してやってください）

ラズパイから Wake on LAN パケットを送る
--------------------------

ググると `etherwake` というコマンドを使えば良さそうだとわかります。前回使った `dietpi-software` コマンドではそれらしいパッケージは見つかりませんでした。でも DietPi では `apt` が使えるのでこれでインストールできました。

```
apt install etherwake
```

etherwake の使い方はこんな感じ

```
usage: etherwake [-i ] [-p aa:bb:cc:dd[:ee:ff]] 00:11:22:33:44:55
   Use '-u' to see the complete set of options. 
```

起動させたい PC の MAC アドレスを調べて引数でわたせば OK. 早速試しましたが起動しない... 私のラズパイには有線LANポートもあるので `-i wlan0` とインターフェースを指定してやる必要がありました。

VPN 接続時に自動で PC を起こしたい
---------------------

さて、コマンドを実行すれば起動させられることはわかりました。でも VPN 接続後にわざわざ SSH してコマンドを打つのも面倒です。WebUI 作って実行ですらやりたくありません。

OpenVPN 接続時に任意のコマンドをサーバー側で実行させる機能はないものかと調べたらありました。

`--client-connect` で接続時のコマンドを `--client-disconnect` で切断時のコマンドを実行できるようです。危険なコマンドを不用意に実行してしまわないようになっており、任意の外部コマンドを実行する場合は `--script-security 2` と指定する必要があるようです。

* **0** -- Strictly no calling of external programs.
* **1** -- (Default) Only call built-in executables such as ifconfig, ip, route, or netsh.
* **2** -- Allow calling of built-in executables and user-defined scripts.
* **3** -- Allow passwords to be passed to scripts via environmental variables (potentially unsafe).

OpenVPN の起動コマンドの引数を変更する必要があります。私の使っている DietPi は systemd が採用されているためこれのカスタマイズには `systemctl edit` コマンドを使います。Unit は `openvpn@server.service` だったので次のようにします。

```
systemctl edit openvpn@server.service
```

これで、エディタが立ち上がるので次のように入力して保存して終了します。

```
[Service]
ExecStart=
ExecStart=/usr/sbin/openvpn --daemon ovpn-%i --status /run/openvpn/%i.status 10 --cd /etc/openvpn --config /etc/openvpn/%i.conf --writepid /run/openvpn/%i.pid --client-connect /etc/openvpn/on-connect.sh --script-security 2
```

これで `/etc/systemd/system/openvpn@server.service.d/override.conf` というファイルに保存されます。

etherwake は root で実行する必要があるため sudo の設定も行います。`sudoedit /etc/sudoers.d/openvpn`

```
nobody ALL=(root) NOPASSWD: /usr/sbin/etherwake
```

後は `/etc/openvpn/on-connect.sh` にコマンドを書いて実行権限をつけれやり、OpenVPN を再起動すれば完了！

接続時のコマンド実行時は環境変数でクライアント名や接続元IPアドレスなど多くの情報を取得可能でした。

参考サイト
-----

*   [OpenVPN の接続・切断時に Slack に通知する](https://blog.ymyzk.com/2016/10/openvpn-slack-notification/)
