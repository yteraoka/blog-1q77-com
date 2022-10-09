---
title: 'TP-Link Deco M5 の V1 と V2 の違いって何だ？'
date: Sun, 07 Oct 2018 15:33:43 +0000
draft: false
tags: ['WiFi']
---

以前にも書いたように我が家にはメッシュ WiFi システムの [TP-Link Deco M5 3台セット](https://amzn.to/2QxPD5a) を導入したわけですが、ふと Amazon のページを開いてみると「この商品には新しいモデルがあります」という表示が！

{{< figure src="deco-m5-v2.png" alt="Deco M5 v2" >}}

新しいモデル？？ [Deco M9](https://www.tp-link.com/us/products/details/cat-5700_Deco-M9-Plus.html) ならそうだが、M5 に新しいモデルがあるのか？

よく見ると末尾に V2.0 とある。そういえばハードウェアに V1, V2 っていうのが存在するというのは知っている。[ファームウェアのダウンロードページ](https://www.tp-link.com/us/download/Deco-M5.html)に行くと V1, V2 ってのがあるから持ってるものに合わせてダウンロードしてねとなっている。そして、V1 と V2 のどちらなのかは地域によって異なるのだよと書かれている。接頭辞に `V` を使ったのが良くないと思うんだけど、これは新しさを表すものではなかった

それでは何がちがうのか？それぞれのデータシートをダウンロードして比較してみましょう

* [Deco M5\_V1\_Datasheet.pdf](https://static.tp-link.com/Deco%20M5_V1_Datasheet.pdf)
* [Deco M5\_V2\_Datasheet.pdf](https://static.tp-link.com/2018/201804/20180420/Deco%20M5%202.0.pdf)

### 結果発表

違いは電源供給ポートが USB Type-C (V1) であるか、一般的なDCの丸いやつか (V2) という差でしかありませんでした。我が家のモデルは V1 でした。壁に書けてあるので USB の方が抜けにくそうだしこっちで良かった。

新しいって書かれて、さらにそっちの方が安いので私が購入する際にもそれがあったら V2 を買っていただろうなあ、危ない危ない

[How to find the hardware version on a TP-Link device?](https://www.tp-link.com/us/faq-46.html)
我が家の危機の型番は `Deco M5(3-pack)(JP) Ver:1.1`
