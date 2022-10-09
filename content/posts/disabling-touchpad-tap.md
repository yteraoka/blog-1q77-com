---
title: 'TouchPad の Tap を無効にする'
date: Wed, 12 Dec 2012 14:40:19 +0000
draft: false
tags: ['Linux', 'Linux Mint']
---

VAIO T11 の Pad が大きくて、ホームポジションのちょい右寄りにあるので右手のハラが触れて誤操作してしまうので無効にする方法を調べてみた。```
synclient MaxTapTime=0

```を ~/.xprofile に書けば OK