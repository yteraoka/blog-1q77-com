---
title: 'OCSP and CRL Performance Report'
date: Tue, 08 Jan 2013 15:48:21 +0000
draft: false
tags: ['Linux', 'SSL']
---

[は参考になった。SSL の仕組みからするとそういう通信は発生するはずだよなぁとは思いつつも調べて見ることはしてこなかった。(まぁ、今回もちょっと調べるだけだけど) しかし、『安い証明書だと中間証明書というものが入っており』は間違いでしょ。GlobalSignだって3階層、EVは4階層で、VeriSignも同様。](http://d.hatena.ne.jp/tkng/20130108/1357610340 "なぜあなたがウェブサイトをHTTPS化するとサイトが遅くなってユーザーが逃げていくのか - 射撃しつつ前転") GlobalSign 以外はこれを速くするってことにあまり積極的じゃないのかな？ [OCSP and CRL Performance Report](https://revocation-report.x509labs.com/) を見ると GlobalSign が圧倒的!! VeriSign 傘下以外はアクセスが少ないから速いのかなぁ? 200ms 以上の差って大きいな。

```
GLobalSign: 76ms
VeriSign / Thawte: 299ms
GeoTrust / RapidSSL: 295ms
```

あのスピード狂の Google が使ってるのは Thawte だけど、一度アクセスすればしばらくキャッシュされるからそれほど重要じゃなかったのだろうか。False Start, OCSP preloading, Snap Start なんかで対応してるんですね。

ワイルドカード証明書にしておけばキャッシュの範囲が広くて有利?
[OCSP verification with OpenSSL](http://backreference.org/2010/05/09/ocsp-verification-with-openssl/) に OpenSSL を使って OCSP 検証する方法が載ってる。試してみたけどへーって感じで... トレンドマイクロの年間固定で同一組織なら無制限でEVでも取得し放題っていうのが気になってる。

まぁ、普通の人は RapidSSL とかの安さに負けるよねぇ。

追記

このサイト超便利 [WebPagetest - Website Performance and Optimization Test](http://www.webpagetest.org/) ここも参考になる [SSL Performance Case Study | Insouciant](https://insouciant.org/tech/ssl-performance-case-study/) Google って最近のは Google Internet Authority が発行してるんですね ![](/wp-content/uploads/2013/01/Google-Authority.png)
