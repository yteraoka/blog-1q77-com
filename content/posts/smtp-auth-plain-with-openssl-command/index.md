---
title: "openssl s_client で SMTP 認証"
description: |
  openssl コマンドで SMTP 認証 (PLAIN) のテストを行う方法
date: 2024-01-23T11:44:23+09:00
draft: false
tags: [AWS, SMTP, ssl]
image: cover.png
author: "@yteraoka"
categories:
  - IT
---

## Amazon SES での SMTP 認証情報の確認をしたい

Amazon SES で SMTP を使ってメール送信したい場合、IAM User の credentials をちょいと加工してやる必要があります。

[Amazon SES SMTP 認証情報を取得](https://docs.aws.amazon.com/ja_jp/ses/latest/dg/smtp-credentials.html)

これで、変換した値が正しいことを確認するために実際にメールの送信を試すわけですが、使えるメール送信ツールがないという場合に openssl コマンドでやればいっかということでメモ。

## SMTP AUTH の PLAIN で渡す文字列

SMTP 認証は PLAIN 方式とすることにしたので次のコマンドの出力を AUTH PLAIN コマンドの引数として渡します。

```bash
printf "${USERNAME}\0${USERNAME}\0${PASSWORD}" | base64 -w 0
```

## OpenSSL コマンドで認証のテスト

接続は port 587 に対して STARTTLS を使います。

```bash
openssl s_client \
  -connect email-smtp.ap-northeast-1.amazonaws.com:587 \
  -starttls smtp -crlf -quiet
```

ここで `-quiet` か `-ign_eof` をつけない場合、terminal から `R` とか `Q` を type した際に renegotiate や close 扱いとなり、切断されてしまうので注意。(RCPT TO コマンドを送ろうとして失敗します)  
OpenSSL が version 3.2 であれば `-nocommands` でも可。([openssl s_client / CONNECTED-COMMANDS](https://www.openssl.org/docs/man3.2/man1/openssl-s_client.html#CONNECTED-COMMANDS-BASIC))

あとは普通の SMTP 通信なので

```
> EHLO example.com
< 250-email-smtp.amazonaws.com
< 250-8BITMIME
< 250-STARTTLS
< 250-AUTH PLAIN LOGIN
< 250 Ok
> AUTH PLAIN (上記で base64 encode した値)
< 235 Authentication successful.
> MAIL FROM: sender@example.com
< 250 Ok
> RCPT TO: receipient@example.com
< 250 Ok
> DATA
< 354 End data with <CR><LF>.<CR><LF>
> Subject: test
>
> test
> .
< 250 Ok xxxxx
> QUIT
< 221 Bye
```

てな具合です。
