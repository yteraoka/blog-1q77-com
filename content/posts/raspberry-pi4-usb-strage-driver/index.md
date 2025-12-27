---
title: "Raspberry Pi 4 での USB Strage Driver"
description: |
  ラズパイで SATA SSD を USB 接続した際にハングアップしてしまう問題への対応
date: 2024-07-20T19:19:30+09:00
tags: ["Raspberry Pi", "Linux"]
draft: false
image: cover.png
author: "@yteraoka"
categories:
  - Home IT
---

## ラズパイが時々ハングアップする

おうちの Raspberry Pi4 は USB で SSD Driver を接続して Samba で File Server にしているわけですが
多くの Read/Write を行うとなぜか OS ごと Hangup するという問題がありました。

最初は電源不足かなと思って電源を交換したりもしたのですが改善しませんでした。
電源は TP-Link の [HS105](https://www.tp-link.com/jp/home-networking/smart-plug/hs105/) 経由にしているのでハングアップしたらリモートで電源 Off / On して復旧させていたわけですが不便なのでググって別の解決策を探してみたところそれらしいものがあったのでメモ。(HS105 は生産も終了しており、後継は [Tapo P110M](https://amzn.to/4f9IQuG) のようです)

## USB Attached SCSI と USB Controller チップの相性問題

- [(SOLVED) Rpi 4 large file transfer makes system hang - Raspberry Pi Forums](https://forums.raspberrypi.com/viewtopic.php?t=324549)

[UAS (USB Attached SCSI)](https://ja.wikipedia.org/wiki/USB_Attached_SCSI) という USB Storage アクセスのための規格があるらしいのですが、これがうまく機能しない場合があるとのことでこれを使わないようにすることで改善することがあるみたい。

ということで設定してみる。

Bus 01 の Dev 3 が USB Storage で `Driver=uas` となっていることが確認できる

```
# lsusb -t
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 5000M
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/1p, 480M
    |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 4: Dev 3, If 0, Class=Mass Storage, Driver=uas, 480M
```

設定のためには Device の ID が必要なので `lsusb` コマンドで確認する。前のコマンドで確認したように Bus 001 の Device 003 なので ID は `152d:0578` になる

```
# lsusb
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 003: ID 152d:0578 JMicron Technology Corp. / JMicron USA Technology Corp. JMS578 SATA 6Gb/s
Bus 001 Device 002: ID 2109:3431 VIA Labs, Inc. Hub
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```

`/boot/cmdline.txt` に `usb-storage.quirks=152d:0578:u` を追記する

```
root=PARTUUID=a1646b47-02 rootfstype=ext4 rootwait net.ifnames=0 logo.nologo console=tty1
↓
root=PARTUUID=a1646b47-02 rootfstype=ext4 rootwait net.ifnames=0 logo.nologo console=tty1 usb-storage.quirks=152d:0578:u
```

reboot すると反映される

`Driver=usb-storage` になっていることが確認できる

```
# lsusb -t
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 5000M
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/1p, 480M
    |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/4p, 480M
        |__ Port 4: Dev 3, If 0, Class=Mass Storage, Driver=usb-storage, 480M
```

ところで、Storage の接続されている Bus が USB 2.0 の方なので、3.0 の方が良いんじゃね？と気づいたので差し替える

```
# lsusb -t
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 5000M
    |__ Port 2: Dev 2, If 0, Class=Mass Storage, Driver=usb-storage, 5000M
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/1p, 480M
    |__ Port 1: Dev 2, If 0, Class=Hub, Driver=hub/4p, 480M
```

これでしばらく様子を見てみることにする

ところで、先のラズパイのフォーラムでは次のようにも書かれており、ちょっと不安。Driver 変更で改善したと書いている人も JMicron なので改善はするのかなと期待はするものの...

> Just in case any of them use the JMicron chipset(s) that are known not to "play well" with Linux

私の環境は SATA の Samsung  SSD 860 EVO 500G を [UGREEN のケース](https://amzn.to/4cNbMqN)に入れて接続しているのですが、このケースで JMicron の chipset が使われているらしい

> UGREEN 2.5 インチ hdd ケース 2.5インチ HDD/SSD 外付けケース USB3.0 UASP対応 5Gbps高速転送 ハードディスクケース SATA III 9.5mm 7mm HDD/SSD対応 工具不要 USB-A ケーブル一体型

## 参考

- [How to bind to the right USB storage driver](https://smitchell.github.io/how-to-bind-to-the-right-usb-storage-driver)


## 補足

後日 [ASM1153E](https://www.asmedia.com.tw/product/7B6yQ54sX7YiFhGD/d1Eyq85QN8GhBwRC) の搭載された USB アダプタを購入したところ UAS でも問題なく機能してくれました

- [ハードディスクアダプタ、プラグアンドプレイASM1153Eチップワイド適用性USB3.0 TO SATA for SSD for HDD](https://amzn.to/42H4i6B)
- [ハードディスクアダプタ、USB3.0 TO SATA ASM1153Eチップワイド適用性6Gbps転送速度プラグアンドプレイ)HDD用SSD用)](https://amzn.to/4aCLp6H)
