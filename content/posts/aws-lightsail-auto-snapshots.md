---
title: 'AWS Lightsail の snapshot 取得を自動化する'
date: Wed, 15 May 2019 15:33:55 +0000
draft: false
tags: ['AWS']
---

[https://github.com/amazon-archives/lightsail-auto-snapshots](https://github.com/amazon-archives/lightsail-auto-snapshots) を使うと非常に簡単。

[awscli](https://github.com/aws/aws-cli) がインストール済みで、認証設定もされているとすると、README に書いてあるように次のように実行すれば CloudFormation で lambda と CloudWatch Event がセットアップされて、すべての Lightsail インスタンスを定期的に取得し、古いものを削除してくれる。

```
git clone https://github.com/amazon-archives/lightsail-auto-snapshots.git
cd lightsail-auto-snapshots
AWS\_PROFILE=default REGION=ap-northeast-1 DAYS=15 SCHEDULE="cron(0 19 \* \* ? \*)" bin/deploy

```

`SCHEDULE` は UTC なので、上記の例では日本時間の早朝4時となる。`DAYS=15` で取得後15日を過ぎると削除される。