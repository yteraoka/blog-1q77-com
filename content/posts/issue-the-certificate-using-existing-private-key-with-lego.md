---
title: lego で既存の秘密鍵を使って証明書を発行する
date: 2022-12-07T22:42:05+09:00
draft: false
tags: ["Certificate", "lego"]
---

既存の秘密鍵を使って証明書を発行しなければいけないという特殊な環境ですぐに証明書を発行したいということがありました。

[lego](https://github.com/go-acme/lego) を使っての証明書発行はとても簡単ですが、デフォルトでは秘密鍵を新規に作成してしまいます。

`lego --help` を確認すると `--csr` オプションがあることがわかりました。これを使えばできました。

## 秘密鍵を作成する

既存の鍵を使うという話ですが、作る方法も書いておく。今回の特殊な環境では RSA 限定。

```
openssl genrsa -out key.pem 2048
```

## CSR を作成する

```bash
openssl req -new -key key.pem \
  -out www.example.com.csr \
  -subj "/CN=www.example.com"
```

今は CommonName ではなく、SAN (Subject Alternative Name) を使うべきらしいですが今回はマルチドメインでもないので
Let's Encrypt 側が証明書作成時にやってくれることに期待します。(実際入ってました)  
DV 証明書なので subject の CN 以外は指定していない。

## lego で証明書発行

Google Cloud の DNS サービスで DNS01 の場合  
(`--dns` で指定するのは `clouddns` ではなく `gcloud`)

```bash
GCE_PROJECT=my-gcp-project lego \
  --path $HOME/.lego \
  --email username@example.com \
  --accept-tos \
  --dns gcloud \
  --dns.resolvers 8.8.8.8 \
  --csr www.example.com.csr \
  run
```

AWS の Route53 で DNS01 の場合

```bash
lego \
  --path $HOME/.lego \
  --email username@example.com \
  --accept-tos \
  --dns route53 \
  --dns.resolvers 8.8.8.8  \
  --csr www.example.com.csr \
  run
```
