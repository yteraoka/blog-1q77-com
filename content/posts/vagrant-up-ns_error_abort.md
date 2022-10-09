---
title: 'VirtualBox 4.2.14 で Vagrant が NS_ERROR_ABORT で up にコケる'
date: Thu, 27 Jun 2013 15:56:29 +0000
draft: false
tags: ['Linux', 'Vagrant']
---

**2013-07-09 追記**

2013-07-04 に VirtualBox 4.2.16 がリリースされていて、vagrant up に失敗する問題も修正されています。
ノートPCの OS を入れ直したので再度 Vagrant 環境を構築してみたら `vagrant up` で

```
NS_ERROR_ABORT
```

となって起動しませんでした。 調べてみたら GitHub に issue がありました。
[The latest upgrade to Virtualbox on Arch Linux breaks vagrant boxes](https://github.com/mitchellh/vagrant/issues/1863) 2013年6月21日リリースの VirtualBox 4.2.14 にバグがあるようです。
VirtualBox を一つ前の 4.2.12 に入れ替えたら起動しました。 今回はこんなマルチホームな vm を起動してみた。

```ruby
  config.vm.define :node1 do |node|
    node.vm.box = "centos6"
    node.vm.network :forwarded_port, guest: 22, host: 2001, id: "ssh"
    node.vm.network :public_network, :bridge => "wlan0", ip: "192.168.0.101"
    node.vm.network :private_network, ip: "192.168.33.11"
  end

  config.vm.define :node2 do |node|
    node.vm.box = "centos6"
    node.vm.network :forwarded_port, guest: 22, host: 2002, id: "ssh"
    node.vm.network :public_network, :bridge => "wlan0", ip: "192.168.0.102"
    node.vm.network :private_network, ip: "192.168.33.12"
  end
```

前に試したときは Multi-Machine 設定はなぜかエラー（名前を指定して個別に起動すれば2つ起動した）になってたのが直ってる。
（気がする、前の設定に問題があったのかどうかはもはや不明）

* [Vagrant メモ (1)](/2013/03/vagrant-1/)
* [Vagrant メモ (2)](/2013/03/vagrant-2/)
