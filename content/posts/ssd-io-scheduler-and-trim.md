---
title: 'SSD だから I/O Scheduler の変更と Trim を有効にする'
date: Tue, 25 Jun 2013 15:42:02 +0000
draft: false
tags: ['Linux', 'Linux Mint']
---

Linux Mint 15 を入れてる Note PC は SSD なのだけれど、Linux で Trim コマンドってどうなってるんだろうと調べてみたら

* Trim コマンドを使うためには discard オプションをつけてマウントする  
  ただし、使えるのは ext4 だけ
* SSD なら I/O スケジューラーを noop にするのが良い

という事だったので設定してみました。 まずは現在の I/O scheduler を確認してみる

```
$ cat /sys/block/sda/queue/scheduler
noop [deadline] cfq 
```

Linux Mint 15 は Ubuntu 13.04 ベースなので default の I/O scheduler を変更するためには `/etc/default/grub` に `elevator=noop` の設定を入れる。

```
$ echo 'GRUB_CMDLINE_LINUX="elevator=noop"' | sudo bash -c "cat >> /etc/default/grub"
$ sudo update-grub
```

で再起動後に確認。

```
$ cat /sys/block/sda/queue/scheduler 
[noop] deadline cfq
```

外付け HDD とか繋げたら

```
$ sudo bash -c "echo deadline > /sys/block/sd?/queue/scheduler"
```

とかした方が良いのかな？ 次に Trim コマンドを有効にするため、fstab のマウントオプションに discard を追加する。 再起動無しで変更するには

```
$ sudo mount -o remount,discard /
$ mount | grep ' on / '
/dev/sda2 on / type ext4 (rw,errors=remount-ro,discard)
```

パフォーマンスの計測などは行なっていない。
