---
title: "Oracle JRE/JDK が Let's Encrypt に対応してない件"
date: Thu, 14 Apr 2016 14:32:16 +0000
draft: false
tags: ['Java', "Let's Encrypt", 'SSL']
---

[Let's Encrypt](https://letsencrypt.org/) が Beta 期間を無事終了し正式公開となったようですが、Oracle の JRE/JDK が Trusted root CA として Let's Encrypt で使われているものを含んでいません。 先週 LINE の [BOT API](https://developers.line.me/bot-api/overview) が公開されて多くの方がこぞって試されていたようですが Let's Encrypt の証明書を使った場合には Callback へのアクセスがないと報告されています。私も試しましたが、ダメでした。 これもおそらく Oracle の Java が [Let's Encrypt で使われている](https://letsencrypt.org/certificates/) [DST Root CA X3](https://www.identrust.com/certificates/trustid/root-download-x3.html) も [ISRG Root X1](https://letsencrypt.org/certs/isrgrootx1.pem.txt) も含んでいないからではないかと勝手に推測してます。 Community にもいくつか thread が立ってます [Will the cross root cover trust by the default list in the JDK/JRE?](https://community.letsencrypt.org/t/will-the-cross-root-cover-trust-by-the-default-list-in-the-jdk-jre/134) 私は Java のコードを書けませんが、簡単なテストコードが公開されていたのでこれを試してみました。 [http://alvinalexander.com/blog/post/java/simple-https-example](http://alvinalexander.com/blog/post/java/simple-https-example)

```
$ mkdir foo
$ vi foo/JavaHttpsExample.java
$ javac foo/JavaHttpsExample.java
$ java foo/JavaHttpsExample
```

Oracle の JRE/JDK では次のようなエラーとなります。

```
Exception in thread "main" javax.net.ssl.SSLHandshakeException:
sun.security.validator.ValidatorException: PKIX path building failed:
sun.security.provider.certpath.SunCertPathBuilderException: unable to
find valid certification path to requested target
```

OpenJDK ではアクセスできました。

```
$ java -version
openjdk version "1.8.0_77"
OpenJDK Runtime Environment (build 1.8.0_77-b03)
OpenJDK 64-Bit Server VM (build 25.77-b03, mixed mode)
```

クライアント側が keystore に登録すればアクセスできるわけですが、Let's Encrypt を使おうとされているサーバーに Java のクライアントがいる場合は要注意です。 LINE Bot でもうちょい遊びたいから RapidSSL 更新しなきゃ。
