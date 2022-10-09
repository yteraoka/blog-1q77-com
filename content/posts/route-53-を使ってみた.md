---
title: 'Route 53 を使ってみた'
date: Sun, 03 Feb 2013 15:06:02 +0000
draft: false
tags: ['AWS', 'DNS', 'Route53', 'aws', 'dns']
---

[【試してみた】Amazon Route 53にドメインを移動してみた。 | Pocketstudio.jp log3](http://pocketstudio.jp/log3/2012/03/31/migrationg_an_existing_domain_to_route53/) を見て、お、私も試してみようと。 簡単すぎて上記のブログ以上に書くことがない... 個人のドメインはお名前.comのサービス使ってたし、めったにいじることもないから運用面で特に変わるところはないんだけど、費用がどの程度かかるのかは様子見かな。 さて、お仕事のドメインを Route 53 に移すかどうかだな。 BIND とかの運用なくせるなら良いけど内部用 DNS サーバーは必要だし、AWS のサービスとて 100% 信頼できるわけじゃないからなぁ。 でもこれらが全部落ちることはないから大丈夫か。

*   ns-1464.awsdns-55.org.
*   ns-1541.awsdns-00.co.uk.
*   ns-315.awsdns-39.com.
*   ns-754.awsdns-30.net.

ついでに AWS 用アカウントを [Google Authenticator](https://itunes.apple.com/us/app/google-authenticator/id388497605?mt=8) で2要素認証にしてみた。