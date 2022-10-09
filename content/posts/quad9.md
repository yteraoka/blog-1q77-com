---
title: 'Quad9 (9.9.9.9) でセキュリティ強化'
date: Thu, 23 Nov 2017 02:00:42 +0000
draft: false
tags: ['DNS']
---

「[DNS resolver 9.9.9.9 will check requests against IBM threat database](https://www.theregister.co.uk/2017/11/20/quad9_secure_private_dns_resolver/)」という記事を見かけたので使ってみることにしました。 DNS サーバーとして 9.9.9.9 を使うことで、ブラウザで誤って怪しいリンクをクリックしてしまうとか、フィッシングに気づかずクリックしてしまった場合でも Quad9 の持っているリストにマッチすればIPアドレスを返さないことでアクセスをブロックできることになります。 もちろんすべての怪しいサイトがブロックされるわけではないですし、IPアドレスでリンクがはられているものには効果がないですが、https 対応していればIPアドレスでのリンクということもないでしょうし、ある程度の効果は見込めそうです。 家族もスマホやタブレットで無線LANを使ってインターネットへアクセスするので DHCP サーバー側（ルーター）でこのDNSサーバーを使うようにしました。 IBM のプレスリリースはこちら 「[IBM、Packet Clearing House、Global Cyber Alliance、インターネットの脅威から企業と消費者を保護するために協業](http://www-03.ibm.com/press/jp/ja/pressrelease/53396.wss)（無数の悪意あるWebサイトからユーザーを保護する Quad9 DNSプライバシー＆セキュリティー・サービス）」 Quad9 のサイトは [https://www.quad9.net/](https://www.quad9.net/) Google も [Public DNS サービス](https://developers.google.com/speed/public-dns/) (8.8.8.8, 8.8.4.4) を提供してくれておりキャッシュポイズニングやサーバー保護系の対策が取られています。([Security Benefits](https://developers.google.com/speed/public-dns/docs/security)) Google には [DNS-over-HTTPS](https://developers.google.com/speed/public-dns/docs/dns-over-https) なんてもあります。

```
λ curl -s https://dns.google.com/resolve?name=www.google.com | jq .
{
  "Status": 0,
  "TC": false,
  "RD": true,
  "RA": true,
  "AD": false,
  "CD": false,
  "Question": [
    {
      "name": "www.google.com.",
      "type": 1
    }
  ],
  "Answer": [
    {
      "name": "www.google.com.",
      "type": 1,
      "TTL": 299,
      "data": "172.217.25.100"
    }
  ],
  "Comment": "Response from 216.239.36.10."
}
```

ちなみに、上のコマンド (curl や jq) は Windows でやってます。

[前回書いた Cmder で](/2017/11/using-cmder/)。便利。

ブラウザでアクセスするならこっち [https://dns.google.com/query?name=www.google.com&type=A&dnssec=true](https://dns.google.com/query?name=www.google.com&type=A&dnssec=true)
