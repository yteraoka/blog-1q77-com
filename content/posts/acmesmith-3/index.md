---
title: 'Acmesmith で証明書発行を試す - その3'
date: Mon, 08 Feb 2016 16:23:13 +0000
draft: false
tags: ['AWS', 'KMS', 'S3', 'SSL', 'ACME', 'Route53']
---

過去2回 Acmesmith を filesystem, S3 を storage として試してきました。 [Acmesmith で証明書発行を試す - その1](/2016/02/acmesmith-1/) (filesystem) [Acmesmith で証明書発行を試す - その2](/2016/02/acmesmith-2/) (S3) 証明書の秘密鍵はセキュアな管理がが必要なので KMS (Key Management Service) を使って S3 に保存することを試してみます。 まずは AWS の IAM Console にある「Encryption Keys（暗号化キー）」にてキーを作成します（リージョンに注意しましょう）。 作成時の設定でキーの利用者に Acmesmith で使う IAM ユーザーを指定しておきます（後からでも設定可能です）。 後は key id （11111111-2222-3333-4444-555555555555 みたいなやつ）を acmesmith.yml に設定するだけです。

```yaml
endpoint: https://acme-v01.api.letsencrypt.org/

storage:
  type: s3
  bucket: BUCKET-NAME
  region: ap-northeast-1
  use_kms: true
  kms_key_id: 11111111-2222-3333-4444-555555555555

challenge_responders:
  - route53: {}

account_key_passphrase:
certificate_key_passphrase:
```

`kms_key_id` だけを設定しておくと `account.pem` （Let's Encrypt のアカウント用秘密鍵）も証明書用の秘密鍵もこの KMS キーで暗号化されます。`kms_key_id_account` と `kms_key_id_certificate_key` をそれぞれ別のキーに設定すると別々のキーで暗号化されます。証明書の秘密鍵はダウンロードさせるけど Let's Encrypt へのアクセスは権限を分けたいと行った場合に使えそうです。勝手に Revoke されないようにとか。 `acmesmith.yml` の準備ができたらこれまでと同様に `register`, `authorize`, `request` すれば証明書がゲットできます。 S3 Console で詳細を確認すると「サーバー側の暗号化: AWS KMS マスターキーの使用: acmetest」と表示されていました。暗号化されているようです。サーバーサイド暗号となっているのでキーへのアクセス権あれば透過的に扱えます。コンソールからダウロードしたらデコードされています。

{{< figure src="account.pem-kms.png" caption="account.pm" >}}

`cert.pem`, `chain.pem`, `fullchain.pem`, `key.pem` が作成されますが暗号の必要な `key.pem` だけが暗号化されています。

{{< figure src="acmesmith-certs.png" caption="certs" >}}

使うだけじゃなくて revoke とか renew とかのコマンド追加の PR ができれば (2016/06/10 追記) 私なんかがやらなくてもどんどん改善されてました 0.4.0 での help はこんな出力 0.3.0 で autorenew や add-san が追加され、0.4.0 では save-pkcs12 が追加されてます

```
$ bundle exec acmesmith help
Commands:
  acmesmith add-san COMMON_NAME [ADDITIONAL_SANS]       # request renewal of ...
  acmesmith authorize DOMAIN                            # Get authz for DOMAIN.
  acmesmith autorenew                                   # request renewal of ...
  acmesmith current COMMON_NAME                         # show current versio...
  acmesmith help [COMMAND]                              # Describe available ...
  acmesmith list [COMMON_NAME]                          # list certificates o...
  acmesmith register CONTACT                            # Create account key ...
  acmesmith request COMMON_NAME [SAN]                   # request certificate...
  acmesmith save-certificate COMMON_NAME --output=PATH  # Save certificate to...
  acmesmith save-pkcs12 COMMON_NAME --output=PATH       # Save ceriticate and...
  acmesmith save-private-key COMMON_NAME --output=PATH  # Save private key to...
  acmesmith show-certificate COMMON_NAME                # show certificate
  acmesmith show-private-key COMMON_NAME                # show private key

Options:
  -c, [--config=CONFIG]                                    
                                                           # Default: ./acmesmith.yml
  -E, [--passphrase-from-env], [--no-passphrase-from-env]  # Read $ACMESMITH_ACCOUNT_KEY_PASSPHRASE and $ACMESMITH_CERTIFICATE_KEY_PASSPHRASE for passphrases
```
