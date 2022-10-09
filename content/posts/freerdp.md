---
title: 'FreeRDP でリモートデスクトップ'
date: Sat, 16 Sep 2017 00:12:56 +0000
draft: false
tags: ['Linux', 'Ubuntu']
---

Linux からのリモートデスクトップ接続には [rdesktop](http://www.rdesktop.org/) を使ってきたが接続先環境の変更によって

```
ERROR: CredSSP: Initialize failed, do you have correct kerberos tgt initialized ?
Failed to connect, CredSSP required by server.
```

というエラーで接続できなくなってしまったので [FreeRDP](http://www.freerdp.com/) に切り替えた。

Ubuntu 17.04 では `apt install freerdp2-x11` でインストールした。

```
rdesktop -k ja -x 0x80 -g 1350x700 -z -a 16 -u {USERNAME} -d {DOMAIN} {SERVER}:{PORT}
```

を

```
xfreerdp /size:1350x700 /u:{USERNAME} /d:{DOMAIN} /v:{SERVER}:{PORT} \
  /bpp:16 /gdi:hw /compression-level:2 +fonts -wallpaper
```

てな感じにしてみた。 関連：[rdesktop コマンドで font smoothing を有効にする](/2014/04/rdesktop-font-smoothing/) Ctrl と CapsLock を入れ替えているのが RDP 先に適用されないのが辛い
