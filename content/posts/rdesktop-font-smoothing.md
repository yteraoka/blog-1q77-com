---
title: 'rdesktop コマンドで font smoothing を有効にする'
date: Wed, 02 Apr 2014 16:24:46 +0000
draft: false
tags: ['Linux']
---

Linux の rdesktop コマンドで Windows 7 にリモートデスクトップ接続する際の font smoothing を有効にする方法です。

ググったら [rdesktop: Connect to Windows 7 and Vista with ClearType font smoothing enabled](https://katastrophos.net/andre/blog/2008/03/10/rdesktop-connect-to-windows-vista-with-cleartype-font-smoothing-enabled/) っていうそのまんまのブログがヒットするわけですけど...

```
rdesktop -x 0x8F mywinserver   # equals the modem default + font smoothing
rdesktop -x 0x81 mywinserver   # equals the broadband default + font smoothing
rdesktop -x 0x80 mywinserver   # equals the LAN default + font smoothing
```

って書いてあるので `-x 0x80` オプションを追加してあげればイケます。 これだとネットワーク的にちょっと重いよという場合は 0x8F とか 0x81 で。 このフラグはこんなことになってるらしいので好きな組み合わせでどうぞ。 私は 0x80 でしか試してない。でも壁紙なんていらないし、ドラッグのやつもメニューのアニメーションもカーソルの影も不要だから 0xAF で良かったかな。

```
#define RDP5_DISABLE_NOTHING	0x00
#define RDP5_NO_WALLPAPER	0x01
#define RDP5_NO_FULLWINDOWDRAG	0x02
#define RDP5_NO_MENUANIMATIONS	0x04
#define RDP5_NO_THEMING		0x08
#define RDP5_NO_CURSOR_SHADOW	0x20
#define RDP5_NO_CURSORSETTINGS	0x40	/* disables cursor blinking */
#define RDP5_ENABLE_FONT_SMOOTHING 0x80
```
