---
title: 'Google Cloud でメールサーバー'
date: 
draft: true
tags: ['Uncategorized']
---

[Cloud Identity](https://cloud.google.com/identity) をプライベートでも使ってみているのですが、Google Workspace とは違って Gmail などが使えないため、メールをなんとかして受信できるようにする必要があります。とりあえず [Amazon SES](https://aws.amazon.com/jp/ses/) で受けて [Amazon SNS](https://aws.amazon.com/jp/sns/) に流して JSON を Gmail に送るということで凌いでいましたが、いかんせん不便です。届いたメール本文の JSON から元のメールを復元する必要がありました。

Lambda で parse して SES で送り直すということでも良かったのですが、Google Cloud の Compute Engine でずっと無料の f1-micro インスタンスをメールサーバーにしちゃおうかな、ということでやってみました。

とは言うものの、Compute Engine からは 25/tcp, 465/tcp, 587/tcp 宛ての Outbound が閉じられているらしいのです。

で、どうすれば良いかと言うと SendGrid などに対して relay するようにするのだそうです。

[インスタンスからのメールの送信](https://cloud.google.com/compute/docs/tutorials/sending-mail) にて SendGrid, Mailgun, Mailjet を使う方法が紹介されています。SendGrid の場合は [Google Cloud Marketplace](https://console.cloud.google.com/marketplace/details/sendgrid-app/sendgrid-email) から登録すると、1月あたり12,000通まで無料で送れるプランになります。直接申し込むと1日あたり100通まで(30日で3,000通)。(私は後から知ったので作り直しましたw)

と、これを書きながらまた確認したら[日本語のサイト](https://sendgrid.kke.co.jp/plan/)では直接でも12,000通/月になってますね、謎...

さて、Google のドキュメントで Postfix を使って relay させることは出来ますが、