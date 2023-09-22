---
title: 'kano を DietPi でサーバーにした'
date: Sat, 10 Mar 2018 13:21:14 +0000
draft: false
tags: ['Linux']
---

[kano](https://kano.me/) っていう子供向け Rasberry Pi キットをその昔買っていました。

スクラッチもマインクラフトもできるし息子が遊んでくれるかなって。

{{< figure src="20141119_075905.jpg" caption="kano package" >}}

しかしながら、数回起動させただけでずっと眠っていました。だってくっそ遅いんですもの。。。

```
root@DietPi:~# cat /proc/cpuinfo
processor       : 0
model name      : ARMv6-compatible processor rev 7 (v6l)
BogoMIPS        : 898.66
Features        : half thumb fastmult vfp edsp java tls
CPU implementer : 0x41
CPU architecture: 7
CPU variant     : 0x0
CPU part        : 0xb76
CPU revision    : 7

Hardware        : BCM2835
Revision        : 000e
Serial          : 00000000ae952dff
Model           : Raspberry Pi Model B Rev 2
```

（今のモデルはもっと快適だと思いますが） 息子はスクラッチもマインクラフトも別の Windows PC でやってます。

で、Google Home で遊ぶためのツールやサーバーを動かしておくためにこれを使おうと [DietPi](http://dietpi.com/) でセットアップしてみました（「[ラズパイZeroでもサクサク動く、軽量Linux「DietPi」](http://tech.nikkeibp.co.jp/it/atcl/column/17/041900152/101900027/)」で紹介されてました）。イメージファイルをダウンロードして Win32 Disk Imager などで SD カードに入れて起動するだけです。後はほぼ Wizard でセットアップできます。

[IMG形式のイメージファイルをUSBメモリやSD/CFカードへ書き込める「Win32 Disk Imager」](https://forest.watch.impress.co.jp/docs/review/1067836.html)

kano のキーボードは中央が膨らんでしまってました。バッテリーが膨らんだ？？？

{{< figure src="DSC_2337.jpg" >}}

{{< figure src="DSC_2339.jpg" >}}

{{< figure src="DSC_2340.jpg" >}}

kano OS はフリーらしいので試してみたい方はどうぞ

* [【Raspberry Pi】Kano OSをインストールしてみた（前編）](https://studio.beatnix.co.jp/kids-it/hardware/raspberry_pi/kano-os01/)
* [【Raspberry Pi】Kano OSをインストールしてみた（後編）](https://studio.beatnix.co.jp/kids-it/hardware/raspberry_pi/kano-os02/)
