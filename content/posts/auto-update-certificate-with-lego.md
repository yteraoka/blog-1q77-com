---
title: 'lego で Let''s Encrypt の証明書を自動更新'
date: Wed, 13 Jul 2016 15:53:37 +0000
draft: false
tags: ['Linux', 'nginx', 'TLS']
---

後でやろうと思ってたら忘れてこのサイトの証明書の期限が切れてしまってました...😢 ということで自動更新の方法をメモ。公式ツールの [certbot](https://github.com/certbot/certbot) はまだ名前変わる前のベータの時に試してみたけど個人的にはちょと大げさすぎて too much だなと思っていたので golang で書かれたシングルバイナリの [lego](https://github.com/xenolf/lego) を使うことにしました。（おもちゃの LEGO ではありませんが、nodejs のやつみたいに商標問題に発展してしまわないかすこし心配です） 以前[試した](/2016/02/acmesmith-1/) [Acmesmith](https://github.com/sorah/acmesmith) も悪くないのですがこのサイトは AWS じゃないので外しました。 lego の使い方は簡単です まずはダウンロード、GitHub のリリースページから最新版をダウンロードし展開すれば準備完了

```
$ curl -LO https://github.com/xenolf/lego/releases/download/v0.3.1/lego_linux_amd64.tar.xz
$ tar xvf lego_linux_amd64.tar.xz
lego/
lego/README.md
lego/LICENSES.txt
lego/CHANGELOG.md
lego/lego
```

```
$ lego/lego
NAME:
   lego - Let's Encrypt client written in Go

USAGE:
   lego/lego [global options] command [command options] [arguments...]
   
VERSION:
   v0.3.1-0-g96a2477
   
COMMANDS:
   run		Register an account, then create and install a certificate
   revoke	Revoke a certificate
   renew	Renew a certificate
   dnshelp	Shows additional help for the --dns global option
   help, h	Shows a list of commands or help for one command
   
GLOBAL OPTIONS:
   --domains, -d [--domains option --domains option]
      Add domains to the process
   --server, -s "https://acme-v01.api.letsencrypt.org/directory"
      CA hostname (and optionally :port). The server certificate must be
      trusted in order to avoid further modifications to the client.
   --email, -m
      Email used for registration and recovery contact.
   --accept-tos, -a
      By setting this flag to true you indicate that you accept the
      current Let's Encrypt terms of service.
   --key-type, -k "rsa2048"
      Key type to use for private keys. Supported: rsa2048, rsa4096,
      rsa8192, ec256, ec384
   --path "/root/.lego"
      Directory to use for storing the data
   --exclude, -x [--exclude option --exclude option]
      Explicitly disallow solvers by name from being used.
      Solvers: "http-01", "tls-sni-01".
   --webroot
      Set the webroot folder to use for HTTP based challenges to write
      directly in a file in .well-known/acme-challenge
   --http
      Set the port and interface to use for HTTP based challenges to
      listen on. Supported: interface:port or :port
   --tls
      Set the port and interface to use for TLS based challenges to
      listen on. Supported: interface:port or :port
   --dns
      Solve a DNS challenge using the specified provider. Disables all
      other challenges. Run 'lego dnshelp' for help on usage.
   --help, -h
      show help
   --version, -v
      print the version

```

`lego` は `dns-01`, `http-01`, `tls-sni-01` に対応していますが、ここは Web サーバーなので `--webroot` を使ってドメイン認証を行うことにします。 `--webroot` で指定するディレクトリに `.well-known/acme-challenge/UeXvRgha4wjQIaKKM31vNubrtvd3C2KrDZpFnscJTBU` といったファイルが一時的に作成されてドメインの所有確認が行われます。 Let's Encrypt のサーバーから確認のためのアクセスがくるためアクセスできるように nginx の設定を事前に行っておく必要があります。 次のように `/.well-known/acme-challenge/` 配下へのアクセスが `--webroot` で指定したディレクトリを root とするようにします。

```
location /.well-known/acme-challenge/ {
    root /etc/lego/webroot;
}
```

すでに HTTPS 化されており、HTTP でアクセスされたら HTTPS に redirect されるようになっていても問題ありません。redirect に対応していました。

```
host:66.133.109.36
time:2016-07-13T15:01:58+00:00
method:GET
uri:/.well-known/acme-challenge/y9FLqXFbJ806v6qfWl-Qt-DR5mMscJ5nsnWODmXxUT0
protocol:HTTP/1.1
status:301
ref:-
ua:Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)
https:

host:66.133.109.36
time:2016-07-13T15:01:59+00:00
method:GET
uri:/.well-known/acme-challenge/y9FLqXFbJ806v6qfWl-Qt-DR5mMscJ5nsnWODmXxUT0
protocol:HTTP/1.1
status:200
ref:http://www.teraoka.me/.well-known/acme-challenge/y9FLqXFbJ806v6qfWl-Qt-DR5mMscJ5nsnWODmXxUT0
ua:Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)
https:on
```

さて、準備ができたところで初回の証明書発行です。

```
# mkdir /etc/lego
# mkdir /etc/lego/webroot
# lego/lego --path /etc/lego \
   --email user@example.com \
   --domains www.example.com \
   --webroot /etc/lego/webroot \
   --accept-tos run
2016/07/13 14:06:31 No key found for account user@example.com. Generating a curve P384 EC key.
2016/07/13 14:06:31 Saved key to /etc/lego/accounts/acme-v01.api.letsencrypt.org/user@example.com/keys/user@example.com.key
2016/07/13 14:06:32 [INFO] acme: Registering account for user@example.com
2016/07/13 14:06:33 !!!! HEADS UP !!!!
2016/07/13 14:06:33 
		Your account credentials have been saved in your Let's Encrypt
		configuration directory at "/etc/lego/accounts/acme-v01.api.letsencrypt.org/user@example.com".
		You should make a secure backup	of this folder now. This
		configuration directory will also contain certificates and
		private keys obtained from Let's Encrypt so making regular
		backups of this folder is ideal.
2016/07/13 14:06:34 [INFO][www.example.com] acme: Obtaining bundled SAN certificate
2016/07/13 14:06:34 [INFO][www.example.com] acme: Trying to solve HTTP-01
2016/07/13 14:06:36 [INFO][www.example.com] The server validated our request
2016/07/13 14:06:36 [INFO][www.teraoka.me] acme: Validations succeeded; requesting certificates
2016/07/13 14:06:38 [INFO] acme: Requesting issuer cert from https://acme-v01.api.letsencrypt.org/acme/issuer-cert
2016/07/13 14:06:38 [INFO][www.example.com] Server responded with a certificate.
# 
```

これだけでOK😄 `--path` で指定するディレクトリに `certificates` というディレクトリができ、そこへ `www.example.com.crt`, `www.example.com.json`, `www.example.com.key` というファイルができ、`accounts` ディレクトリ配下にアカウントの private key などが生成されます。 更新は renew コマンドです。

```
# lego/lego --path /etc/lego \
   --email user@example.com \
   --domains www.example.com \
   --webroot /etc/lego/webroot \
   renew
```

不要になったり、漏洩しちゃったりしたら revoke しましょう

```
# lego/lego --path /etc/lego \
   --email user@example.com \
   --domains www.example.com \
   revoke
```

では更新を自動化しましょう。 雑に書くとこんな感じでいけます

```
#!/bin/sh

file=$(find /etc/lego/certificates/www.example.com.crt -type f -mtime +80)
if [ -n "$file" ] ; then
    lego --path /etc/lego \
      --email user@example.com \
      --domains www.example.com \
      --webroot /etc/lego/webroot \
      renew
    nginx -s reload
fi
```

あまりに頻繁に renew すると拒否されるようになるので気をつけましょう

```
2016/07/13 15:03:24 acme: Error 429 - urn:acme:error:rateLimited - Error creating new cert :: Too many certificates already issued for exact set of domains: www.example.com
```
