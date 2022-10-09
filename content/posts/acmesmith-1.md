---
title: 'Acmesmith で証明書発行を試す - その1'
date: Wed, 03 Feb 2016 16:42:28 +0000
draft: false
tags: ['AWS', 'Route53', 'SSL', 'acme', 'aws', 'route53', 'ssl']
---

無料でSSL証明書の発行ができる [Let's Encrypt](https://letsencrypt.org/) が Public Beta となり、これからどんどん利用されていくと思われますが、公式(?)のツール [https://github.com/letsencrypt/letsencrypt](https://github.com/letsencrypt/letsencrypt) はちょっと使いにくいところがありました。 DigitalOcean にも解説記事 [How To Secure Nginx with Let's Encrypt on CentOS 7](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-centos-7) がありましたが、あのツールでは HTTP でのドメイン認証となり、証明書を取得しようとしているドメイン(FQDN)が外部 (Let's Encrypt 側のサーバー) からアクセス可能状態でなければなりません。 外部に公開していない、できないサーバーであったり、ロードバランサーの背後にあったり、Web じゃなくてメールサーバーとか LDAP サーバーで使いたいのにという場合に不便でした。 そんななか sorah さんが [Acmesmith](https://github.com/sorah/acmesmith) という便利ツールを公開されていたので早速試してみることにしました。 [ACME Protocol](https://github.com/ietf-wg-acme/acme) では HTTP でのドメイン確認の他に DNS の TXT レコードを使う方法も規定されています。Acmesmith はこの DNS での処理を AWS Route53 を使うことによってレコードの追加削除まで自動で行ってくれるツールとなっています。さらに、鍵と証明書を S3 に保存することも、それを KMS によってセキュアに管理することにも対応しています。 今回はまずローカルファイルに証明書を書き出す方法でやってみます。 使い方は README に書いてありますね。 Ruby gems で公開されているのでまずは Gemfile を書いて `bundle install` します。```
$ cat Gemfile
source 'https://rubygems.org'
gem 'acmesmith'
$ bundle install --path vendor/bundle

````bundle exec acmesmith help` を実行してみる```
$ bundle exec acmesmith help
Commands:
  acmesmith authorize DOMAIN              # Get authz for DOMAIN.
  acmesmith current COMMON\_NAME           # show current version for certificate
  acmesmith help \[COMMAND\]                # Describe available commands or on...
  acmesmith list \[COMMON\_NAME\]            # list certificates or its versions
  acmesmith register CONTACT              # Create account key (contact e.g. ...
  acmesmith request COMMON\_NAME \[SAN\]     # request certificate for CN +COMMO...
  acmesmith show-certificate COMMON\_NAME  # show certificate
  acmesmith show-private-key COMMON\_NAME  # show private key

Options:
  -c, \[--config=CONFIG\]                                    
                                                           # Default: ./acmesmith.yml
  -E, \[--passphrase-from-env\], \[--no-passphrase-from-env\]  # Read $ACMESMITH\_ACCOUNT\_KEY\_PASSPHRASE and $ACMESMITH\_CERT\_KEY\_PASSPHRASE for passphrases

```(revoke がまだ実装されていないのかな) コンフィグファイルが必要なので `acmesmith.yml` を作成します。```
endpoint: https://acme-v01.api.letsencrypt.org/

storage:
  type: filesystem
  path: /home/ytera/acmesmish/certs

challenge\_responders:
  - route53: {}

account\_key\_passphrase:
certificate\_key\_passphrase:

````aws_access_key` の中に `access_key_id`, `secret_access_key` を書くこともできますが aws-sdk を使っているので `~/.aws/credentials` があればそれを使ってくれます。 Route53 の操作のために IAM に必要な policy を設定しておく必要があります。これも README に全部書かれています。[https://github.com/sorah/acmesmith#all-access-s3--route53-setup](https://github.com/sorah/acmesmith#all-access-s3--route53-setup) `acmesmith.yml` で `storage` の `path` に指定したディレクトリは予め作成しておく必要があります。 まずは `register` サブコマンドでアカウントを作成します。 `path` 配下に `account.pem` が作成されます。アカウントは公開鍵認証のようです。 `account_key_passphrase` が空であれば暗号化されずに保存されます。 次にドメインの認証です、ドメインは証明書のコモンネームに指定するものです。```
$ bundle exec acmesmith authorize www.teraoka.me
=> Responding challenge dns-01 for www.teraoka.me in Acmesmith::ChallengeResponders::Route53
 \* UPSERT: TXT "\_acme-challenge.www.teraoka.me", "\\"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ\\"" on /hostedzone/XXXXXXXXXXXXXX
 \* requested change: /change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*
=> Waiting for change
 \* change "/change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*" is still "PENDING" ...
 \* change "/change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*" is still "PENDING" ...
 \* change "/change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*" is still "PENDING" ...
 \* change "/change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*" is still "PENDING" ...
 \* change "/change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*" is still "PENDING" ...
 \* change "/change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*" is still "PENDING" ...
 \* synced!
=> Requesting verification...
 \* verify\_status: valid
=> Cleaning up challenge dns-01 for www.teraoka.me in Acmesmith::ChallengeResponders::Route53
 \* DELETE: TXT "\_acme-challenge.www.teraoka.me", "\\"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ\\"" on /hostedzone/XXXXXXXXXXXXXX
 \* requested: /change/\*\*\*\*\*\*\*\*\*\*\*\*\*\*
=> Done

```ドメインの前に `_acme-challenge.` をつけた `TXT` レコードを作成し、validation のリクエストを出して、成功したら不要となった `TXT` を早速削除しています。ゴミが残らなくて良いですね。 このあと```
$ bundle exec acmesmith request www.teraoka.me

```と実行すれば完了です。証明書が `certs/certs/www.teraoka.me/` の配下に保存されています。 Let's Encrypt ではワイルドカード証明書の発行はできませんが SAN で複数ドメインの証明書は発行可能です。```
$ bundle exec acmesmith request www.teraoka.me www.1q77.com

```と実行したら```
X509v3 Subject Alternative Name: 
    DNS:www.1q77.com, DNS:www.teraoka.me

```という証明書が発行されました。 あー、楽ちん。 sorah さんありがとう 今度 AWS KMS (Key Management Service) を使ってセキュアに保存する方法を KMS の勉強がてら試してみよう。 [つづき](/2016/02/acmesmith-2/) ところで acmesmith ってなんて読むんだ？