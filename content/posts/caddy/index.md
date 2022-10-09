---
title: 'Caddy という高機能 HTTPS サーバー'
date: Sat, 29 Apr 2017 15:35:42 +0000
draft: false
tags: ['Caddy', 'TLS']
---

{{< figure src="caddy.png" >}}

[https://caddyserver.com/](https://caddyserver.com/) なにやら大変便利そうなものがありました。

* HTTP/HTTPS サーバー
* TLS 証明書の自動更新が可能 (HTTP, DNS 両方対応)
* HTTP2, QUIC, WebSocket にも対応
* Go で書かれているのでマルチプラットフォーム対応
* 単純なディレクトリの公開
* Markdown のレンダリングが可能
* [ダイナミックな証明書取得](https://caddyserver.com/docs/automatic-https#on-demand) (Let's Encrypt はワイルドカード証明書に対応していないが、リクエストを受けた時点でそのドメインの証明書を取得するということでワイルドカードっぽく使える)
* リバースプロキシ
* ロードバランス
* Basic認証
* 他
* Plugin による拡張
  * IPアドレス制限
  * ratelimit
  * ファイルアップロード、削除
  * CGI
  * などなど

[https://github.com/caddyserver/examples](https://github.com/caddyserver/examples) ここに各種設定例があります。でも古いかも。
設定ファイルのデフォルトはカレントディレクトリの `Caddyfile` です。
ファイルはなくても引数や標準入力からでも渡せます。
何も指定せずに単に `caddy` と実行すればカレントディレクトリをドキュメントルートとして 2015/tcp で http サーバーが起動します。
`caddy browse` とすればディレクトリを指定した場合にファイルのリストが表示されます。

{{< figure src="caddy-browser.png" caption="caddy file browser" >}}

`caddy browse markdown` とすれば更に、アクセスしたファイルが .md だった場合に markdown を HTML にして表示してくれます。（独立したオプションなので `browse` を外せばファイルのリストは表示されませんが、markdown の HTML 化はされます）

### このサイトに Caddy を導入してみる

Apache + PHP の手前に nginx を置いた構成なので、nginx を caddy に置き換えるだけです。 Caddyfile を次のようにし、ダウンロードした caddy の tar.gz に入っている `init/linux-systemd/caddy.service` を使い `ExecStart` に `-quic` を追加し、実行ユーザーを変えただけです。

```
blog.1q77.com {
  proxy / localhost:8080 {
    header_upstream Host {host}
    header_upstream X-Forwarded-Proto {scheme}
  }
  log / /var/log/caddy/access.log "remote_addr:{remote}	time:{when_iso}	method:{method}	uri:{uri}	protocol:{proto}scheme:{scheme}	status:{status}	host:{host}	h_host:{>Host}	size:{size}	latency:{latency}	mitm:{mitm}	ua:{>User-Agent}	cookie:{>Cookie}" {
    rotate_size 100 # rotate after 100MB
    rotate_age 30 # keep 30 days
  }
}
```

ログは LTSV にしてみました。[placeholder の一覧](https://caddyserver.com/docs/placeholders)。
`X-Forwarded-Proto` を追加していますが `X-Forwarded-For` は `header_upstream` 設定なしで付きます。
証明書は環境変数 `CADDYPATH` で `/etc/ssl/caddy` が指定してあるのでここにファイルができていました。

```
# find /etc/ssl/caddy/ -type f
/etc/ssl/caddy/acme/acme-v01.api.letsencrypt.org/users/default/default.json
/etc/ssl/caddy/acme/acme-v01.api.letsencrypt.org/users/default/default.key
/etc/ssl/caddy/acme/acme-v01.api.letsencrypt.org/sites/blog.1q77.com/blog.1q77.com.crt
/etc/ssl/caddy/acme/acme-v01.api.letsencrypt.org/sites/blog.1q77.com/blog.1q77.com.key
/etc/ssl/caddy/acme/acme-v01.api.letsencrypt.org/sites/blog.1q77.com/blog.1q77.com.json
/etc/ssl/caddy/ocsp/blog.1q77.com-815f526b
```

### QUIC プロトコル

UDP でより効率的な TCP を再設計（TCP を改善するには標準化や各OSでの対応を待つ必要があり、大変時間がかかるのでアプリケーションレイヤーｄやってしまおうという）したようなプロトコルで主に Google のサイトとモバイル端末の間で使われているプロトコルですが、Caddy では実験的なサポートがされています。
`-quic` オプションをつけて起動すると有効になります。
次のようなヘッダーが返るようになって動作しているみたいですが

```
Alt-Svc: quic=":443"; ma=2592000; v="36,35"
Alternate-Protocol: 443:quic
```

Chrome で見ると Broken と表示されてしまいました。なんでだろ？
{{< figure src="alternate-service-mapping.png" >}}
chrome://net-internals/#alt-svc
[https://github.com/mholt/caddy/wiki/QUIC](https://github.com/mholt/caddy/wiki/QUIC)

### DNS を使った証明書取得

これが便利だなと思っています。Let's Encrypt のサーバーからアクセスできるサーバーであれば [certbot](https://certbot.eff.org/) なり何なりで自動化は容易ですが、アクセスできない場合は [dns-01](https://tools.ietf.org/html/draft-ietf-acme-acme-03#section-7.4) によるドメインの所有確認が必要です。certbot とスクリプトを組み合わせることでこれもできるようですが Web サーバーだけで簡単にできちゃうのは便利そうです。まだ試してないけど沢山の DNS プロバイダに対応しています。

[https://github.com/caddyserver/dnsproviders](https://github.com/caddyserver/dnsproviders)

[CertbotでDNSによる認証(DNS-01)で無料のSSL/TLS証明書を取得する | 本日も乙](http://blog.jicoman.info/2017/04/certbot_dns_01/)

Route53 は IAM で編集可能な範囲を制限するのが zone 単位なので example.com を持っていて www.example.com を dns-01 で所有確認するのであれば www.example.com を別 zone に切り出して権限を付与するのが安全でしょう、万が一 IAM 情報が漏れてしまっても影響範囲を限定できます。

### まとめ

パフォーマンスとか安定性は良くわからないけど社内向けサーバーなんかで使ってみるのはいいんじゃないかなと。特に外からアクセスできないような場合。
