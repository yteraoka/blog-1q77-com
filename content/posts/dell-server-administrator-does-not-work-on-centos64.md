---
title: 'CentOS 6.4 で DELL の ServerAdministrator が動かなかった件'
date: Wed, 05 Jun 2013 14:11:54 +0000
draft: false
tags: ['Linux', 'DELL', 'IPMI']
---

最近セットアップするのは仮想のゲストOSばっかりだったから気づかなかったけど、CentOS 6.4 (RHEL 6.4) では DELL の ServerAdministrator (OpenManage) が動かなくなっていた。 調べてみると IPMI 周りに問題があるようで、6.3 までだと kernel module に ipmi\_si.ko が存在したのに、6.4 では存在しなくなっていることから起こっている問題っぽい。

```
# find /lib/modules/`uname -r`/ -name '*ipmi*'
/lib/modules/2.6.32-358.6.2.el6.x86_64/kernel/drivers/char/ipmi
/lib/modules/2.6.32-358.6.2.el6.x86_64/kernel/drivers/char/ipmi/ipmi_devintf.ko
/lib/modules/2.6.32-358.6.2.el6.x86_64/kernel/drivers/char/ipmi/ipmi_poweroff.ko
/lib/modules/2.6.32-358.6.2.el6.x86_64/kernel/drivers/char/ipmi/ipmi_watchdog.ko
```

古い kernel には ipmi\_si.ko がある

```
# modinfo ipmi_si | grep description
description:    Interface to the IPMI driver for the KCS, SMIC, and BT system interfaces.
```

で、「ipmi\_si.ko」をキーワードにググると出てきますね [Red Hat Enterprise Linux 6.4 breaks Dell Openmanage | robklg](http://robklg.wordpress.com/2013/02/27/red-hat-enterprise-linux-6-4-breaks-dell-openmanage/) ここの本文にある対策でも動くようになりますが、コメントにある「OpenIPMI」をインストールする方法で対応しておきましょう。 それから、srvadmin の最新版(7.2)を試してみたらこれまで通りに

```
$ sudo yum install srvadmin-storage
```

を実行しただけでは omreport コマンドがインストールされませんでした。 細かく別れたみたいです。そして依存関係情報に問題があるっぽく、別途

```
$ sudo yum install srvadmin-omacore srvadmin-storage-cli
```

が必要なようです。 DELL の Linux 情報は [http://linux.dell.com/](http://linux.dell.com/) (HP よりはわかりやすい。気がしてる) HPとかのツールでも同じ問題はあったっぽい。
