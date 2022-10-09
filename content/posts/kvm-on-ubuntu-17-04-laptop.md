---
title: 'Ubuntu 17.04 に KVM をインストール'
date: Sat, 13 May 2017 02:45:41 +0000
draft: false
tags: ['KVM', 'Ubuntu']
---

```
$ lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 17.04
Release:	17.04
Codename:	zesty

$ uname -r
4.10.0-20-generic
```

必要なパッケージをインストール

```
$ sudo apt install qemu-kvm virt-manager virt-top
```

`virt-manager` を使うために（たぶんほぼ使わないけど） `libvirt` グループに入っていれば操作できるようにする

```
$ sudoedit /etc/libvirt/libvirtd.conf
```

```
# Default allows only owner (root), do not change it unless you are
# sure to whom you are exposing the access to.
#unix_sock_admin_perms = "0700"
```

ここの `unix_sock_admin_perms` を `0770` に書き換えて `libvirtd` を再起動する
