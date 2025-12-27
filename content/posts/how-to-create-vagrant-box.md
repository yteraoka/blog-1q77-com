---
title: 'Vagrant box 作成方法'
date: Sat, 17 Sep 2016 01:07:33 +0000
draft: false
tags: ['Packer', 'VirtualBox', 'boxcutter', 'Vagrant']
---

前にも作ってみたが、もっとイカした作成方法が無いかな？ってのと自分用の Vagrant box を Github に置こうかなと思って調べてたら [https://atlas.hashicorp.com/boxcutter](https://atlas.hashicorp.com/boxcutter) という便利ツールの存在を知った https://github.com/misheska/basebox-packer から https://github.com/box-cutter に移り、今は [https://github.com/boxcutter](https://github.com/boxcutter) となっているようだ そんでもって [https://atlas.hashicorp.com/boxcutter](https://atlas.hashicorp.com/boxcutter) にほぼ最小構成の box が揃ってるから欲しかったのはこれだということでわざわざ作らなくても良くなった... カスタマイズしたくなったら各 distribution の repository を clone して編集して build すれば良さそう。[CentOS](https://github.com/boxcutter/centos) なら [kickstart 用のファイル](https://github.com/boxcutter/centos/tree/master/http) をいじるか [custom-script.sh](https://github.com/boxcutter/centos/blob/master/custom-script.sh) をいじってビルドすれば良い。[ubuntu](https://github.com/boxcutter/ubuntu) の場合は [preseed.cfg](https://github.com/boxcutter/ubuntu/tree/master/http) か [custom-script.sh](https://github.com/boxcutter/ubuntu/blob/master/custom-script.sh) で良さそう。 どちらの場合も custom-script.sh でできることはこっちでやるのがスジだろう

```
bin/box build centos72 virtualbox
```

などとするだけで出来ちゃう！！素晴らしい！！

### [boxcutter](https://atlas.hashicorp.com/boxcutter) で公開されている box を使う方法

```
$ vagrant box add https://atlas.hashicorp.com/boxcutter/boxes/centos72
==> box: Loading metadata for box 'https://atlas.hashicorp.com/boxcutter/boxes/centos72'
This box can work with multiple providers! The providers that it
can work with are listed below. Please review the list and choose
the provider you will be working with.

1) parallels
2) virtualbox
3) vmware_desktop

Enter your choice: 2
==> box: Adding box 'boxcutter/centos72' (v2.0.15) for provider: virtualbox
    box: Downloading: https://atlas.hashicorp.com/boxcutter/boxes/centos72/versions/2.0.15/providers/virtualbox.box
    box: Progress: 84% (Rate: 4661k/s, Estimated time remaining: 0:00:17)
==> box: Successfully added box 'boxcutter/centos72' (v2.0.15) for 'virtualbox'!
$ vagrant init boxcutter/centos72
A `Vagrantfile` has been placed in this directory. You are now
ready to `vagrant up` your first virtual environment! Please read
the comments in the Vagrantfile as well as documentation on
`vagrantup.com` for more information on using Vagrant.
$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
==> default: Importing base box 'boxcutter/centos72'...
==> default: Matching MAC address for NAT networking...
==> default: Checking if box 'boxcutter/centos72' is up to date...
==> default: Setting the name of the VM: test_default_1474101995245_97755
==> default: Clearing any previously set network interfaces...
==> default: Preparing network interfaces based on configuration...
    default: Adapter 1: nat
==> default: Forwarding ports...
    default: 22 (guest) => 2222 (host) (adapter 1)
==> default: Booting VM...
==> default: Waiting for machine to boot. This may take a few minutes...
    default: SSH address: 127.0.0.1:2222
    default: SSH username: vagrant
    default: SSH auth method: private key
    default: Warning: Remote connection disconnect. Retrying...
    default: 
    default: Vagrant insecure key detected. Vagrant will automatically replace
    default: this with a newly generated keypair for better security.
    default: 
    default: Inserting generated public key within guest...
    default: Removing insecure key from the guest if it's present...
    default: Key inserted! Disconnecting and reconnecting using new SSH key...
==> default: Machine booted and ready!
==> default: Checking for guest additions in VM...
==> default: Mounting shared folders...
    default: /vagrant => /home/ytera/test
```

Ubuntu 16.04 で VirtualBox 5.1.6 ではエラーで起動せず、vagrant も 1.8.5 には authorized\_keys のパーミッション設定に問題があるということでログインできずということでハマってしまったが、それぞれ 5.0 と 1.8.4 にすることで回避
