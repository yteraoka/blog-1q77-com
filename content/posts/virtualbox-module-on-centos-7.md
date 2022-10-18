---
title: 'CentOS 7 の Virtualbox module'
date: Thu, 25 May 2017 14:05:12 +0000
draft: false
tags: ['CentOS','VirtualBox', 'Vagrant']
---

[boxcutter](https://github.com/boxcutter) の CentOS 7 で確認 vboxadd.service vboxadd-service.service という service が入っている。 vboxadd.service では kernel module を build するために gcc, make, kernel-devl パッケージのインストールが必要

```
$ sudo mount -t vboxsf -o uid=1000,gid=1000 vagrant /vagrant
```

でホストのディレクトリをマウントできる
