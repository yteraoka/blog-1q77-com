---
title: 'noip.com で DDNS 設定'
date: Mon, 28 Mar 2016 14:43:33 +0000
draft: false
tags: ['DNS', 'DigitalOcean']
---

[前回](/2016/03/connect-to-private-network-on-digitalocean-using-openvpn/) DigitalOcean にて OpenVPN サーバーをセットアップしました。ずっと起動させっぱなしでも$5/月なわけですが、必要なときにしか起動させない予定です。

shutdown しておくだけだと費用がかかるため snapshot を取得して仮想サーバーは削除してしまいます。必要になったら snapshot から起動させれば IP アドレス以外は元通りになります。

VPN サーバーなので IP アドレスが変わるたびにクライアントの設定を変更するのは面倒です。そこで DDNS っぽいサービスを使って起動時に毎度 DNS を更新することにします。

使うのは [https://www.noip.com/](https://www.noip.com/) にしてみました。 こんな簡単なスクリプトを `/etc/update-noip.sh` として書いて `/etc/rc.local` に書きました。

```bash
#!/bin/sh

USERNAME=foobar
PASSWORD=secret
HOSTNAME=*****.noip.me
MYIP=$(curl -s http://httpbin.org/ip | grep origin | awk '{print $2}' | sed -e 's/"//g')

curl -s -u $USERNAME:$PASSWORD -o /dev/null \
  "https://dynupdate.no-ip.com/nic/update?hostname=$HOSTNAME&myip=$MYIP"
```

90日間更新しないとホスト名が消えちゃうので長期間使わない場合はログインして更新してあげるなりなんなりしてあげる必要があります。有料プランに切り替えればこの制限はなくなります。

DNS は AWS の Route53 を使っているので AWS の API で更新しようかとも思いましたが、IAM でリソース単位の制御はできないということで、ドメインまるごと更新可能なシークレットキーを置いておくのも嫌かなということで今回の構成としました。
