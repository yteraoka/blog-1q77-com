---
title: 'Vagrant メモ (1)'
date: Fri, 22 Mar 2013 15:32:14 +0000
draft: false
tags: ['Vagrant']
---

流行りの Vagrant （[ベイグラント](http://www.howjsay.com/index.php?word=vagrant&submit=Submit)）を試してみる [http://downloads.vagrantup.com/tags/v1.1.2](http://downloads.vagrantup.com/tags/v1.1.2) から vagrant\_x86\_64.deb （手元のPCが Linux Mint なので）をダウンロードしてインストール。

```
$ sudo dpkg -i vagrant_x86_64.deb
```

`/opt/vagrant` にインストールされる。 1.0.x では gem でインストールするという方法もあったけど 1.1.x ではもう gem は提供されないとのこと。

> Gem Install? Vagrant 1.0.x had the option to be installed as a RubyGem. This installation method has been removed for installers and packages only.

```
$ vagrant init centos6 \
  http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20130309.box
A `Vagrantfile` has been placed in this directory. You are now
ready to `vagrant up` your first virtual environment! Please read
the comments in the Vagrantfile as well as documentation on
`vagrantup.com` for more information on using Vagrant.
```

> Vagrantfile がこのディレクトリに作成されました。`vagrant up` コマンドで最初の仮想環境を立ち上げる準備ができました。Vagrantfile のコメント行を読んでね。Vagrant についてもっと知りたかったら `vagrantup.com` にアクセスしてね。

とのことなので

```
$ vagrant up
Bringing machine 'default' up with 'virtualbox' provider...
[default] Box 'centos6' was not found. Fetching box from specified URL for
the provider 'virtualbox'. Note that if the URL does not have
a box for this provider, you should interrupt Vagrant now and add
the box yourself. Otherwise Vagrant will attempt to download the
full box prior to discovering this error.
Downloading with Vagrant::Downloaders::HTTP...
Downloading box: http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20130309.box
Progress: 27% (134439529 / 491722240)

Extracting box...
Cleaning up downloaded box...
Successfully added box 'centos6' with provider 'virtualbox'!
[default] Importing base box 'centos6'...
[default] No guest additions were detected on the base box for this VM! Guest
additions are required for forwarded ports, shared folders, host only
networking, and more. If SSH fails on this machine, please install
the guest additions and repackage the box to continue.

This is not an error message; everything may continue to work properly,
in which case you may ignore this message.
[default] Matching MAC address for NAT networking...
[default] Setting the name of the VM...
[default] Clearing any previously set forwarded ports...
[default] Creating shared folders metadata...
[default] Clearing any previously set network interfaces...
[default] Preparing network interfaces based on configuration...
[default] Forwarding ports...
[default] -- 22 => 2222 (adapter 1)
[default] Booting VM...
[default] Waiting for VM to boot. This can take a few minutes.
[default] VM booted and ready for use!
[default] Configuring and enabling network interfaces...
[default] Mounting shared folders...
[default] -- /vagrant
```

起動したので ssh でログイン

```
$ vagrant ssh
Welcome to your Vagrant-built virtual machine.
[vagrant@localhost ~]$
```

ps で見てみるとこんなコマンドで ssh してました。なるほど。

```
ssh vagrant@127.0.0.1 \
  -p 2222 \
  -o LogLevel=FATAL \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o IdentitiesOnly=yes \
  -i /home/ytera/.vagrant.d/insecure_private_key
```

### Bridgeインターフェースを使う

Vagrantfile を編集して

```
config.vm.network :public_network
```

をアンコメントして起動すると

```
[default] Available bridged network interfaces:
1) wlan0
2) eth0
What interface should the network bridge to?
```

と、どのインターフェースのBridgeとするかの選択肢が出る。 そして NAT のインターフェース(eth0)に加え、Bridge のインターフェース(eth1)が作成される。 （2013-03-23追記） 毎回どのインターフェースを使うか尋ねられると困るので Vagrantfile で指定する

```ruby
config.vm.network :public_network, :bridge => "wlan0"
```

### ゲストOS起動時の出力を見たい

`Vagrantfile` の

```ruby
config.vm.provider :virtualbox do |vb|
  vb.gui = true
end
```

をアンコメントして起動させるとVirtualBoxの仮想ターミナルが起動する。

{{< figure src="screenshot.png" alt="起動画面" >}}

CentOS のこの画面だと起動時のメッセージは見れないので `F1` を押して表示させる。 この他に Vagrantfile ではメモリサイズの変更やホスト側のディレクトリをゲスト側でマウントする設定や Port Forwarding の追加、Puppet や Chef の設定が可能なようです。というか、Puppet や Chef 使うのが目的ですかね。
