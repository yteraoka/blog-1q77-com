---
title: 'mailx コマンドでメール送信テスト'
date: Fri, 28 Feb 2020 14:55:30 +0000
draft: false
tags: ['Linux', 'SMTP', 'SMTP']
---

昔、メールサーバーを管理していた時から使ってた Perl で書いた smtp クライアントがどこに行ったかわからなくなったけど、確か mailx コマンドで出来るっぽかったなということで試してみた。他にも github に何か便利そうなツールがあった気がするけど探し出せない...

試した環境は AmazonLinux 2 です。mailx コマンドは mailx というパッケージに入っています。

```
$ rpm -qf $(which mailx)
mailx-12.5-19.amzn2.x86\_64

```

Google アカウントで SMTP サーバーを使ってメールを送る方法は「[プリンタ、スキャナ、アプリからのメール送信](https://support.google.com/a/answer/176600?hl=ja)」にあります。

送信方法は次の通り。465/tcp の SMTP over SSL/TLS には非対応かな。

```
echo メッセージ本文 \\
| mailx -n -v \\
  -S smtp=smtp.gmail.com:587 \\
  -S smtp-auth=plain \\
  -S smtp-auth-user=username@gmail.com \\
  -S smtp-auth-password=アプリパスワード\\
  -S smtp-use-starttls \\
  -S ssl-verify=ignore \\
  -S nss-config-dir=/etc/pki/nssdb \\
  -S from="表示名 <username@gmail.com>" \\
  -s "サブジェクト" \\
  -c CCメールアドレス \\
  -b BCCメールアドレス
  -a 添付ファイルのpath \\
  宛先メールアドレス

```

日本語など us-ascii 外のバイト列が含まれる場合は自動で charset を utf-8 にしてくれますし、添付ファイルの Content-Type もバイナリなら octet-stream になるし、テキストファイルなら text/plain になります。ヘッダー内の非 ascii は utf-8 の Base64 encode にしてくれます。ステキ。

アプリパスワードについては「[アプリ パスワードでログイン](https://support.google.com/mail/answer/185833)」を参照

smtp.gmail.com の EHLO のレスポンスです。通常の SMTP サーバーでは見かけない認証に対応してますね。

```
250-smtp.gmail.com at your service, \[203.0.113.10\]
250-SIZE 35882577
250-8BITMIME
250-AUTH LOGIN PLAIN XOAUTH2 PLAIN-CLIENTTOKEN OAUTHBEARER XOAUTH
250-ENHANCEDSTATUSCODES
250-PIPELINING
250-CHUNKING
250 SMTPUTF8

```