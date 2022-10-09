---
title: 'CentOS 7 メモ'
date: 
draft: true
---

Timezone の設定```
timedatectl set-timezone Asia/Tokyo

```Locale の設定```
localectl status
localectl list-locales
localectl set-locale LANG=ja\_JP.utf8

```ファイルは /etc/locale.conf