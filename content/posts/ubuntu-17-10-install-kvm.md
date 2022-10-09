---
title: 'Ubuntu 17.10 に KVM をインストール'
date: Tue, 31 Oct 2017 15:13:57 +0000
draft: false
tags: ['KVM', 'Linux', 'Ubuntu']
---

以前、「[Ubuntu 17.04 に KVM をインストール](/2017/05/kvm-on-ubuntu-17-04-laptop/)」というのと書いていた。
Ubuntu 17.10 を入れたのでここでも KVM を使えるようにする。

```
$ lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 17.10
Release:	17.10
Codename:	artful
```

```
$ uname -r
4.13.0-16-lowlatency
```

```
$ sudo apt install qemu-kvm libvirt-clients libvirt-bin bridge-utils
```

virt-install を使うためには

```
$ sudo apt install virtinst
```
