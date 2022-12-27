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

## Subject Alternative Name を使った CSR を作成する

せっかくなのでやってみる  
conf ファイルを作る必要があってちょっと面倒  
SAN を追加したいだけなら `[server_request]` の中は `subjectAltName` だけでも大丈夫だけど他のも指定してみた

```bash
cat > san.conf <<'EOF'
[req]
distinguished_name   = server_dn
req_extensions       = server_reqext

[server_dn]
commonName           = www.example.com

[server_reqext]
basicConstraints     = CA:FALSE
keyUsage             = critical,digitalSignature,keyEncipherment
extendedKeyUsage     = serverAuth
subjectKeyIdentifier = hash
subjectAltName       = @alt_names

[alt_names]
DNS.1                = www.example.com
DNS.2                = example.com
EOF
```

```bash
openssl req -new -key key.pem \
  -out www.example.com.csr \
  -subj "/CN=www.example.com" \
  -config san.conf
```

こうして作成すると CSR に Requested Extensions が入っていることが確認できます。

```bash
openssl req -text -noout -in www.example.com.csr
```

```
Attributes:
Requested Extensions:
    X509v3 Basic Constraints:
        CA:FALSE
    X509v3 Key Usage: critical
        Digital Signature, Key Encipherment
    X509v3 Extended Key Usage:
        TLS Web Server Authentication
    X509v3 Subject Key Identifier:
        5A:31:C4:1B:E9:78:56:90:33:57:FB:3B:07:7B:96:CF:96:F6:05:86
    X509v3 Subject Alternative Name:
        DNS:www.example.com, DNS:example.com
```


### ファイルを作らない方法

[Simple, Rolling-Update Production Setup With Docker & Traefik](https://blog.sebastian-daschner.com/entries/rolling-updates-production-traefik) という記事を見ていたら `<()` を使う方法がありました。
shell のこの記法は知っていて diff なんかでは使ってましたが、たまに使えないことがある (file の permission をチェックしてる場合など) ので試してませんでした。
また、`-extensions` で指定すれば `req_extensions` をファイル内での指定を省略できるようです。
記事内では printf が使われていましたが複数行でも見やすい方が良いかと `<<` にしてみた。
あ、あとこれは CSR 作成までじゃなくて自己署名するところまでになってる。

```
openssl req -x509 -out example.com.crt -keyout example.com.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=example.com' -extensions ext -config <( <<EOF
[dn]
CN=example.com
[req]
distinguished_name = dn
[ext]
subjectAltName=DNS:example.com,DNS:*.example.com
keyUsage=digitalSignature
extendedKeyUsage=serverAuth
EOF
)
```

## 参考資料

- [IBM Documentation | マルチドメイン (SAN) SSL 証明書署名要求の作成](https://www.ibm.com/docs/ja/qsip/7.4?topic=sc-creating-multi-domain-san-ssl-certificate-signing-request)
- [Simple, Rolling-Update Production Setup With Docker & Traefik - Sebastian Daschner](https://blog.sebastian-daschner.com/entries/rolling-updates-production-traefik)
