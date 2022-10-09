---
title: 'Linux Mint で無線LANが無効から戻らない'
date: Sun, 16 Dec 2012 13:00:02 +0000
draft: false
tags: ['Linux', 'Linux Mint']
---

ネットワークの設定から無線LANを無効にしてみたら、元に戻せなくなった... 再起動してもダメだった。

```
ifconfig wlan0 up
```

してみたら

```
SIOCSIFFLAGS: Operation not possible due to RF-kill
```

と表示されたので RF-kill でググってみたところ rfkill っていうコマンドがあったので

```
rfkill unblock wifi
```

で戻せました。

```
$ sudo rfkill list
0: sony-wifi: Wireless LAN
	Soft blocked: no
	Hard blocked: no
1: sony-bluetooth: Bluetooth
	Soft blocked: yes
	Hard blocked: no
2: phy0: Wireless LAN
	Soft blocked: no
	Hard blocked: no
```

Bluetooth はタスクバー(?)の Bluetooth アイコンから Off / On できた。

VAIO T11 には無線LANとかを On / Off するハードウェアスイッチがない。
