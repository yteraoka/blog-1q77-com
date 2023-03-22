---
title: "Laptop に Ubuntu 22.04 LTS をセットアップしたメモ"
date: 2023-03-21T23:44:44+09:00
draft: true
tags: ["Ubuntu"]
---

10年ぶりに Laptop を新調して Ubuntu 22.04 LTS をセットアップしたのでメモ

Laptop は DELL の Inspiron 14 です。  
([デル Inspiron 14 AMD (5425) の実機レビュー](https://thehikaku.net/pc/dell/22Ins14-5425.html))

```
$ sudo dmidecode -s system-product-name
Inspiron 14 5425
```

- AMD Ryzen 5 5625U
- 16 GiB メモリ
- NMVe SSD 512 GiB
- 14 インチ 1920x1200 の FHD+
- USB-C 給電対応
- USB-C ポートは左側に1つだけ
- USB-A は左右にひとつずつ（ただし、右側はなんか変）

Windows 11 がプリインストールされていましたが、捨て去りました。

## キーボードカスタマイズ

`A` の左の Caps Lock は Ctrl として使いたいので調整

コンソールアクセスすることがあるかどうかはわからないけど `/etc/default/keyboard` を編集。
`XKBOPTIONS` に `ctrl:nocaps` を設定。

```
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="jp"
XKBVARIANT=""
XKBOPTIONS="ctrl:nocaps"

BACKSPACE="guess"
```

参考

- [Caps-LockキーをCtrlキーにする方法](https://linux.just4fun.biz/?Ubuntu/Caps-Lock%E3%82%AD%E3%83%BC%E3%82%92Ctrl%E3%82%AD%E3%83%BC%E3%81%AB%E3%81%99%E3%82%8B%E6%96%B9%E6%B3%95)

## 日本語入力

Fcitx5 - mozc が良さそうということでインストール

Ubuntu Software ってところから `mozc` で検索すると `Mozc for Fcitx 5` が見つかったのでこれをインストール (依存しているものも当然インストールしてくれます)

`Fcitx 5 Configuration` というのもインストールされているのでこれを起動します。

Current Input Method 側が `Keyboard - Japanese` と `Mozc` だけになるようにします。

{{< figure src="fcitx-configuration.png" alt="Fcitx Configuration" >}}

これだけでは自動で起動してくれなかったので `im-config -n fcitx5` を実行して `~/.xinputrc` を更新した。

中身は次のようになっていた

```
# im-config(8) generated on Tue, 21 Mar 2023 23:34:58 +0900
run_im fcitx5
# im-config signature: b852b5a48a91d5a35974c4946cb98ce8  -
```

参考

- [Ubuntu 21.10でFcitx 5を使用する](https://gihyo.jp/admin/serial/01/ubuntu-recipe/0689)

## Homebrew のインストール

```
sudo apt-get install build-essential procps curl file git
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```


## devbox のインストール

```
curl -fsSL https://get.jetpack.io/devbox | bash
```

- https://www.jetpack.io/devbox/docs/quickstart/


## Google Chrome のインストール

Firefox がデフォルトでインストールされているので Google Chrome を検索し、`.deb` ファイルをダウンロード。
右クリックで Open With Other Application から Software Install を選択。


## スクリーンショットの撮り方

PC には Print Screen ボタンがあるのを忘れてました。

- [【Ubuntu】スクリーンショットとスクリーンキャスト（動画）の撮り方](https://www.server-memo.net/ubuntu/ubuntu_screenshot.html)


## USB-A の右側がおかしい

この Bus 03 側がおかしくて

```
$ lsusb -t
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
```

KIOXIA の TransMemory を右側に挿入したときのログ

```
[ 3992.416782] usb 3-2: new full-speed USB device number 6 using xhci_hcd
[ 3992.552717] usb 3-2: device descriptor read/64, error -71
[ 3992.796722] usb 3-2: device descriptor read/64, error -71
[ 3993.032656] usb 3-2: new full-speed USB device number 7 using xhci_hcd
[ 3993.168738] usb 3-2: device descriptor read/64, error -71
[ 3993.412739] usb 3-2: device descriptor read/64, error -71
[ 3993.520552] usb usb3-port2: attempt power cycle
[ 3993.933117] usb 3-2: new full-speed USB device number 8 using xhci_hcd
[ 3993.933221] usb 3-2: Device not responding to setup address.
[ 3994.140514] usb 3-2: Device not responding to setup address.
[ 3994.348424] usb 3-2: device not accepting address 8, error -71
[ 3994.476423] usb 3-2: new full-speed USB device number 9 using xhci_hcd
[ 3994.476545] usb 3-2: Device not responding to setup address.
[ 3994.684555] usb 3-2: Device not responding to setup address.
[ 3994.892461] usb 3-2: device not accepting address 9, error -71
[ 3994.892576] usb usb3-port2: unable to enumerate USB device
```

KIOXIA の TransMemory を左側に挿入したときのログ

```
[ 4109.209280] usb 1-2: new high-speed USB device number 6 using xhci_hcd
[ 4109.362840] usb 1-2: New USB device found, idVendor=30de, idProduct=6544, bcdDevice= 1.00
[ 4109.362852] usb 1-2: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[ 4109.362855] usb 1-2: Product: TransMemory     
[ 4109.362857] usb 1-2: Manufacturer: KIOXIA  
[ 4109.362860] usb 1-2: SerialNumber: 0022CFF6BD70C6902321DDC7
[ 4109.364017] usb-storage 1-2:1.0: USB Mass Storage device detected
[ 4109.365108] scsi host2: usb-storage 1-2:1.0
[ 4110.540022] scsi 2:0:0:0: Direct-Access     KIOXIA   TransMemory      1.00 PQ: 0 ANSI: 4
[ 4110.540577] sd 2:0:0:0: Attached scsi generic sg0 type 0
[ 4110.541063] sd 2:0:0:0: [sda] 60549120 512-byte logical blocks: (31.0 GB/28.9 GiB)
[ 4110.541350] sd 2:0:0:0: [sda] Write Protect is off
[ 4110.541357] sd 2:0:0:0: [sda] Mode Sense: 45 00 00 00
[ 4110.541577] sd 2:0:0:0: [sda] Write cache: disabled, read cache: enabled, doesn't support DPO or FUA
[ 4110.550190]  sda: sda1 sda2
[ 4110.550338] sd 2:0:0:0: [sda] Attached SCSI removable disk
[ 4110.875349] ntfs3: Unknown parameter 'windows_names'
```

I-O DATA BUM-3D を右側に挿入したときのログ

```
[ 4196.862092] usb 4-2: new SuperSpeed USB device number 75 using xhci_hcd
[ 4196.894525] usb 4-2: New USB device found, idVendor=04bb, idProduct=102e, bcdDevice= 0.02
[ 4196.894536] usb 4-2: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[ 4196.894539] usb 4-2: Product: I-O DATA BUM-3D
[ 4196.894542] usb 4-2: Manufacturer: I-O DATA DEVICE, INC.
[ 4196.894544] usb 4-2: SerialNumber: 22062853040022
[ 4196.895803] usb-storage 4-2:1.0: USB Mass Storage device detected
[ 4196.896211] scsi host2: usb-storage 4-2:1.0
[ 4199.039158] scsi 2:0:0:0: Direct-Access     I-O DATA BUM-3D           8.01 PQ: 0 ANSI: 6
[ 4199.039594] sd 2:0:0:0: Attached scsi generic sg0 type 0
[ 4199.040424] sd 2:0:0:0: [sda] 487424000 512-byte logical blocks: (250 GB/232 GiB)
[ 4199.040634] sd 2:0:0:0: [sda] Write Protect is off
[ 4199.040639] sd 2:0:0:0: [sda] Mode Sense: 23 00 00 00
[ 4199.040837] sd 2:0:0:0: [sda] Write cache: disabled, read cache: enabled, doesn't support DPO or FUA
[ 4199.043602]  sda: sda1
[ 4199.043679] sd 2:0:0:0: [sda] Attached SCSI removable disk
```

I-O DATA BUM-3D を左側に挿入したときのログ

```
[ 4369.773759] usb 2-2: new SuperSpeed USB device number 3 using xhci_hcd
[ 4369.806065] usb 2-2: New USB device found, idVendor=04bb, idProduct=102e, bcdDevice= 0.02
[ 4369.806075] usb 2-2: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[ 4369.806079] usb 2-2: Product: I-O DATA BUM-3D
[ 4369.806081] usb 2-2: Manufacturer: I-O DATA DEVICE, INC.
[ 4369.806083] usb 2-2: SerialNumber: 22062853040022
[ 4369.808017] usb-storage 2-2:1.0: USB Mass Storage device detected
[ 4369.809067] scsi host2: usb-storage 2-2:1.0
[ 4371.967134] scsi 2:0:0:0: Direct-Access     I-O DATA BUM-3D           8.01 PQ: 0 ANSI: 6
[ 4371.967673] sd 2:0:0:0: Attached scsi generic sg0 type 0
[ 4371.968545] sd 2:0:0:0: [sda] 487424000 512-byte logical blocks: (250 GB/232 GiB)
[ 4371.968717] sd 2:0:0:0: [sda] Write Protect is off
[ 4371.968721] sd 2:0:0:0: [sda] Mode Sense: 23 00 00 00
[ 4371.968893] sd 2:0:0:0: [sda] Write cache: disabled, read cache: enabled, doesn't support DPO or FUA
[ 4371.971279]  sda: sda1
[ 4371.971393] sd 2:0:0:0: [sda] Attached SCSI removable disk
```



何も挿してない状態

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


右側の USB-A に I-O DATA BUM-3D を挿した状態

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
    |__ Port 2: Dev 76, If 0, Class=Mass Storage, Driver=usb-storage, 5000M (*)
        ID 04bb:102e I-O Data Device, Inc. 
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


左側の USB-A に I-O DATA BUM-3D を挿した状態

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
    |__ Port 2: Dev 6, If 0, Class=Mass Storage, Driver=usb-storage, 5000M (*)
        ID 04bb:102e I-O Data Device, Inc. 
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


左側の USB-C に I-O DATA BUM-3D を挿した状態

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
    |__ Port 1: Dev 7, If 0, Class=Mass Storage, Driver=usb-storage, 5000M (*)
        ID 04bb:102e I-O Data Device, Inc. 
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


左側の USB-A に BUFFALO SSD-PUT/N を挿した状態

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
    |__ Port 2: Dev 8, If 0, Class=Mass Storage, Driver=uas, 10000M (*)
        ID 0411:031c BUFFALO INC. (formerly MelCo., Inc.) 
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


左側の USB-C に BUFFALO SSD-PUT/N を挿した状態

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
    |__ Port 1: Dev 9, If 0, Class=Mass Storage, Driver=uas, 10000M (*)
        ID 0411:031c BUFFALO INC. (formerly MelCo., Inc.) 
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


左側の USB-C に BUFFALO SSD-PUT/N を挿した状態
で、さらに左側の USB-A にマウスの無線アダプタを挿した状態
なんで Human Interface Device が2つ見えるんだ？

```
$ lsusb -tv
/:  Bus 04.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
/:  Bus 03.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 3: Dev 2, If 0, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 1, Class=Wireless, Driver=btusb, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 3: Dev 2, If 2, Class=Wireless, Driver=, 480M
        ID 0489:e0c8 Foxconn / Hon Hai 
    |__ Port 4: Dev 3, If 0, Class=Vendor Specific Class, Driver=, 12M
        ID 27c6:639c Shenzhen Goodix Technology Co.,Ltd. 
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/2p, 10000M
    ID 1d6b:0003 Linux Foundation 3.0 root hub
    |__ Port 1: Dev 9, If 0, Class=Mass Storage, Driver=uas, 10000M (*)
        ID 0411:031c BUFFALO INC. (formerly MelCo., Inc.) 
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    ID 1d6b:0002 Linux Foundation 2.0 root hub
    |__ Port 2: Dev 7, If 0, Class=Human Interface Device, Driver=usbhid, 12M (*)
        ID 046d:c534 Logitech, Inc. Unifying Receiver
    |__ Port 2: Dev 7, If 1, Class=Human Interface Device, Driver=usbhid, 12M (*)
        ID 046d:c534 Logitech, Inc. Unifying Receiver
    |__ Port 4: Dev 2, If 0, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia 
    |__ Port 4: Dev 2, If 1, Class=Video, Driver=uvcvideo, 480M
        ID 0c45:6739 Microdia
```


