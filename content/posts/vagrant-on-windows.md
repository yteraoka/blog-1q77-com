---
title: 'Windows で Vagrant'
date: Wed, 29 Nov 2017 10:49:15 +0000
draft: false
tags: ['VirtualBox', 'Windows', 'Vagrant']
---

[https://www.vagrantup.com/downloads.html](https://www.vagrantup.com/downloads.html) からインストラーをダウンロードしてインストールすれば普通に使える。が、今の環境では Docker Toolbox のインストールで一緒に入ってた。

### ホスト側フォルダのマウント (vbguest)

ホスト(Windows)側のフォルダを /vargant としてマウントさせるには vagrant-vbguest plugin を入れる必要がある。標準では `vagrant up` に rsync でコピーされるだけで稼働中はホスト側の変更が反映されない。

```
$ vagrant plugin install vagrant-vbguest
Installing the 'vagrant-vbguest' plugin. This can take a few minutes...
Fetching: vagrant-share-1.1.9.gem (100%)
Fetching: micromachine-2.0.0.gem (100%)
Fetching: vagrant-vbguest-0.15.0.gem (100%)
Installed the plugin 'vagrant-vbguest (0.15.0)'!
```

```
$ vagrant plugin list
vagrant-share (1.1.9, system)
vagrant-vbguest (0.15.0)
```

このプラグインを入れると `vagrant up` 時に VirtualBox Guest Additions のインストールが走り、必要なパッケージのインストールや kernel module のコンパイルが行われて遅くなるので不要であれば入れないほうが良いかも。既にインストール済みの場合でも `"C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso"` にあるバージョンと異なる場合は再インストールされます。各バージョンのファイルは [http://download.virtualbox.org/virtualbox/](http://download.virtualbox.org/virtualbox/) からダウンロード可能です。

`vagrant vbguest --status` で GuestAdditions のインストール状況が確認できる

インストールしただけではマウントはされず、次の行を Vagrantfile に追加する必要があります。

```
config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
```

### SSH

Git for Windows についてくる `git-bash.exe` を Terminal として使うと vagrant ssh で接続できるけどプロンプトが表示されないという問題がある。しかし、ssh コマンドでは問題ない。これは大変不便なので `~/.bashrc`

この vagrant ssh の問題はいつのまにか改善していました (2018/9/15 追記)

```bash
vssh() {
  if [ "$1" = "-r" ] ; then
    rm -f ssh_config
    shift
  fi
  test -f ssh_config || vagrant ssh-config | sed 's,C:,/c,' > ssh_config
  ssh -F ssh_config "$@"
}
```

と書いてみた。vagrant コマンドの実行はいちいち遅いので ssh\_config の更新が不要な場合はすぐに ssh できて早いという利点もある。

最近の OpenSSH は .ssh/config ファイルを分割できるらしい [~/.ssh/configについて](https://qiita.com/passol78/items/2ad123e39efeb1a5286b)

`vagrant ssh` が機能するようになったため上記の `vssh()` は不要になったわけですが、`IdentityFile` の path として `C:/Users/...` と書かれていると git-bash についてくる OpenSSH ではアクセスできないため、`/c/Users/...` に置換するようにしました。`C:\Windows\System32\OpenSSH\ssh.exe` の方であれば `C:/Users/...` でもアクセスできました。ただし、こちらの ssh は winpty を使う必要がある。

### Hostonly Network

標準では NAT ネットワークで、ホスト側からアクセスするためにはいちいち port forwarding 設定が必要です。
`Vagrantfile` にある次の行をアンコメントするとホストオンリーネットワークアダプタが作成され

```
# config.vm.network "private_network", ip: "192.168.33.10"
```

NAT 設定不要で `ip:` で指定した IP アドレスにホスト側から直接アクセスできるようになります。

### Bridge Network

セキュリティ的に問題ないとわかっている場合は Bridge Network を使えるようにすることで、他のホストからもアクセスできるようにできます。`Vagrantfile` の次の行をアンコメントすると使えます。

```
# config.vm.network "public_network"
```

こちらは IP アドレスの指定が不要ですが、きっとホストPCのあるネットワークには DHCP サーバーがありますよね

### Box の更新

```
==> default: Checking if box 'centos/7' is up to date...
==> default: A newer version of the box 'centos/7' for provider 'virtualbox' is
==> default: available! You currently have version '1804.02'. The latest is version
==> default: '1809.01'. Run `vagrant box update` to update.
```

```
$ vagrant box update
==> default: Checking for updates to 'centos/7'
    default: Latest installed version: 1804.02
    default: Version constraints:
    default: Provider: virtualbox
==> default: Updating 'centos/7' with provider 'virtualbox' from version
==> default: '1804.02' to '1809.01'...
==> default: Loading metadata for box 'https://vagrantcloud.com/centos/7'
==> default: Adding box 'centos/7' (v1809.01) for provider: virtualbox
    default: Downloading: https://vagrantcloud.com/centos/boxes/7/versions/1809.01/providers/virtualbox.box
    default: Download redirected to host: cloud.centos.org
    default:
==> default: Successfully added box 'centos/7' (v1809.01) for 'virtualbox'!
```

```
$ vagrant box list
centos/7        (virtualbox, 1804.02)
centos/7        (virtualbox, 1809.01)
ubuntu/xenial64 (virtualbox, 20180224.0.0)
```

古いものを消すには

```
$ vagrant box remove centos/7 --box-version 1804.02
```

などとする
