---
title: 'Acmesmith で証明書発行を試す - その2'
date: Sun, 07 Feb 2016 09:00:08 +0000
draft: false
tags: ['AWS', 'Route53', 'S3', 'TLS', 'ACME']
---

前回「[Acmesmith で証明書発行を試す - その1](/2016/02/acmesmith-1/)」で [](https://github.com/sorah/acmesmith)で filesystem に保存する方法を試してみました。 今回は AWS S3 に保存するテストを行ってみます。KMS はまだ使いません。bucket 名は `BUCKET-NAME` として進めます。 `aws s3` コマンドでも操作できるように IAM policy を設定します。README に書いてある policy には `s3:GetBucketLocation` がないために `aws s3` コマンドではアクセスできませんでした。

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::BUCKET-NAME"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::BUCKET-NAME/*"
    }
  ]
}
```

acmesmith.sh の `storage` を S3 用に書き換えます。 認証情報は aws-cli の `~/.aws/credentials` を使うのでここには書きません。`region` は `~/.aws/config` の値は使われないので指定が必要です。

```yaml
endpoint: https://acme-v01.api.letsencrypt.org/

storage:
  type: s3
  bucket: BUCKET-NAME
  region: ap-northeast-1
  use_kms: false

challenge_responders:
  - route53: {}

account_key_passphrase:
certificate_key_passphrase:
```

前回作成したアカウントの `account.pem` が手元にあるのでこれを S3 にコピーしておきます。（新たに作成 (register) しても問題ありません）

```
$ aws s3 cp account.pem s3://BUCKET-NAME/account.pem
$ aws s3 ls s3://BUCKET-NAME/
2016-02-07 17:28:05       1679 account.pem
```

後は同じですね。

```
$ bundle exec acmesmith authorize www2.teraoka.me
$ bundle exec acmesmith request www2.teraoka.me
$ aws s3 ls s3://BUCKET-NAME/
                           PRE certs/
2016-02-07 17:28:05       1679 account.pem
$ aws s3 ls s3://BUCKET-NAME/certs/
                           PRE www2.teraoka.me/
$ aws s3 ls s3://BUCKET-NAME/certs/www2.teraoka.me/
                           PRE 20160207-032600_***********************************/
2016-02-07 13:25:50         51 current
$ aws s3 ls s3://BUCKET-NAME/certs/www2.teraoka.me/20160207-032600_***********************************/
2016-02-07 13:25:49       1797 cert.pem
2016-02-07 13:25:50       1675 chain.pem
2016-02-07 13:25:50       3472 fullchain.pem
2016-02-07 13:25:50       1679 key.pem
```

次回は [KMS (Key Management Service)](https://aws.amazon.com/jp/kms/) を[試します](/2016/02/acmesmith-3/)。
