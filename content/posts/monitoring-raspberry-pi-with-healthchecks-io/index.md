---
title: 'healthchecks.io でラズパイの生死監視'
date: Tue, 02 Mar 2021 15:03:45 +0000
draft: false
tags: ['monitoring']
---

我が家では古いラズパイを [VPN Server](/2019/03/pivpn/) としてや、[定期的に GoogleHome を喋らせたり](/2019/10/google-home-mini-and-text-to-speech/)、Pi-hole サーバーとして使ってたりするのですが、たまにお亡くなりになっていることがあります。あれ？何か DNS がおかしいな、とか、お喋りしないなということで気づいて電源を入れ直していたわけですが、やっぱり異変には早めに気づいて対処したいなと思い [healthchecks.io](https://healthchecks.io/) を使って監視することにしました。

家で常時起動しているサーバー的なものはこのラズパイだけなので他の機器から監視することはできなかったため、cron で healthchecks.io に対して curl でハートビート的なアクセスをして、一定期間音沙汰がないと通知がくる仕組みです。

healthchecks.io の料金プランです。なんと、**Hobbyist** プランなら無料です。ステキ！

{{< figure src="healthchecks-io-pricing.png" >}}

healthchecks.io は定期実行する処理がきちんと実行されているかどうかを確認して通知してくれるサービスです。通知先も Slack, Mattermost, E-mail はもちろん LINE, PagerDuty, Discord, Webhook などなど沢山あります。

healthchecks.io の API に対して cron job などの成功、失敗を連携することで失敗時の通知や、一定期間アクセスがない場合の通知が受けられるというのがメインの機能ですが、数はプランによるものの過去の履歴も確認できますし、job の開始時と終了時に連携すればかかった時間も確認できるし、job の出力などを送ることも可能です。

curl でアクセスするだけでも使えますが、[runitor](https://github.com/bdd/runitor) を使えばこれらの機能を簡単に使えます。

healthchecks のコードは [GitHub](https://github.com/healthchecks/healthchecks) で公開されているため、セルフホストすることも可能ですし、[Terraform provider](https://github.com/kristofferahl/terraform-provider-healthchecksio) まであるみたいです。

この記事を書いていて、このブログのバックアップスクリプトが shell script で結果を slack に垂れ流しているのを [runitor](https://github.com/bdd/runitor) で置き換えようと思いました。

それから、ラズパイが死んでいることに気づいても、電源を入れ直すのが面倒でした。設置場所まで行き、棚の扉を開けて引っ張り出して電源の USB ケーブルを抜き差しするというのが。で、[TP-Link の WiFi スマートプラグ](https://amzn.to/3dYG5Px)を購入しました。

スマートプラグって原始的な照明機器くらいにしか使えないじゃん、誰が買うの？とか思ってたけど買いました。ただ、今のところまだどちらも活躍してない。良いことなんですけど。
