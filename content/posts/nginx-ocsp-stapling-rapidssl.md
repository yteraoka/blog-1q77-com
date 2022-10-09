---
title: 'nginx で OCSP Stapling (RapidSSL)'
date: Thu, 12 Feb 2015 14:46:08 +0000
draft: false
tags: ['nginx', 'SSL', 'ocsp', 'spdy']
---

SSL の有効な HTTP サーバーを nginx で構築する機会があったので OCSP Stapling (と SPDY) を有効にしてみた話。(SPDY は listen に spdy って追加するだけなので特に書くことなし) 環境は CentOS 6 で nginx は nginx.org の mainline RPM (1.7.10)

### OCSP Stapling とは

SSL は信頼できる認証局によって発行された証明書であることを確認することでそのサーバーも信頼できるもの（少なくともそのドメインの所有者の正当なサーバー）とします。 が、その証明書はその後、失効されているかもしれません。鍵が漏れたとかその疑いがある場合などに失効させて再発行してもらいます。OpenSSL の脆弱性さわぎ (Heartbleed) の時には多くの証明書が失効されているはずです。 そのため、失効されてるかどうかを OCSP や CRL によって別途確認する必要があり、クライアントはそのための通信をする必要があるのです。 OCSP Stapling はその通信を不要にしようというものです。Staple はステープラー（ホッチキス）のそれで、束ねて一緒に渡しちゃえというものです。実印を押した書類に印鑑証明を添えて提出するのに似てる？ GlobalSign にもドキュメントがありました [NGINX - Enable OCSP Stapling](https://support.globalsign.com/customer/portal/articles/1642332-nginx---enable-ocsp-stapling)

### nginx での設定

簡単です。SSL の `server { }` の中に

```nginx
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /some/where/trusted.crt;
```

を書くだけです。キモは `ssl_trusted_certigicate` で指定する証明書ファイルです。 RapidSSL は GeoTrust なので Root 証明書はこちら [GeoTrust Root Certificates](https://www.geotrust.com/resources/root-certificates/) RapidSSL の中間証明書は [RapidSSL Intermediate CAs](https://knowledge.rapidssl.com/support/ssl-certificate-support/index?page=content&id=AR1548) から。今回は SHA2 の証明書なので [Intermediate CA Certificates: RapidSSL with SHA-2 (under SHA-1 Root)](https://knowledge.rapidssl.com/support/ssl-certificate-support/index?page=content&actp=CROSSLINK&id=SO26457) の2つ。Root証明書と中間証明書の合計3つを1つのファイルにまとめます。 順番にも気をつける必要があり、先の GlobalSign のドキュメントにも "This must contain the intermediate & root certificates (in that order from top to bottom)" とあります。

```
$ echo QUIT | openssl s_client -connect localhost:443 -status 2> /dev/null | head -n 20
```

これで `OCSP Response Status: successful` という文字列がみつかればうまくいっていそうです。初回やしばらくアクセスのなかった後は `OCSP response: no response sent` が返ってきますが、その次のアクセスでは OCSP Response が返ってきます。 OCSP のデータが付加される分、ネゴシエーション時のトラッフィクが増えるので keep-alive は有効にしましょう。そうでなくても SSL のハンドシェイクは重いようなので。 [Qualys SSL Labs - Projects / SSL Server Test](https://www.ssllabs.com/ssltest/) で確認してみましょう。 HTTPS サーバーの設定例

```nginx
server {
  listen 443 ssl spdy;
  ssl_certificate      /some/where/server.crt;
  ssl_certificate_key  /some/where/server.key;
  ssl_session_cache  shared:SSL:10m;
  ssl_session_timeout  5m;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

  # https://wiki.mozilla.org/Security/Server_Side_TLS
  ssl_ciphers  ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA;
  ssl_prefer_server_ciphers   on;
  add_header Alternate-Protocol  443:npn-spdy/3;
  add_header Strict-Transport-Security "max-age=31536000;";

  # enable ocsp stapling
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_trusted_certificate /some/where/trusted.crt;
}
```
