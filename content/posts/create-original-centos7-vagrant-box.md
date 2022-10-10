---
title: 'CentOS7の自前Vagrant boxを作成する'
date: Thu, 29 Oct 2015 13:30:18 +0000
draft: false
tags: ['Linux', 'vagrant']
---

何が入ってるかわからないイメージじゃなくて自分で作りたいと思ったので作ってみたので自分用にメモ。 ほぼ「[CentOS7.1にてVagrant Base Boxを作成する - とあるエンジニアの技術メモ](http://kan3aa.hatenablog.com/entry/2015/05/29/120212)」に書いてあるままですけど。 まずはインストール用に ISO ファイルをダウンロード [https://www.centos.org/download/](https://www.centos.org/download/) Oracle VM VirtualBox マネージャーで新しい仮想サーバーを作成。ここでは名前を「centos7」とする。 仮想ハードディスクは「VDI」で「可変サイズ」サイズは適当に「16GB」としておいた。 設定を開いてオーディオ、USBを無効化する。フロッピーもチェックを外す。 ダウンロードした ISO ファイルをマウントして起動し、CentOS をインストール 「vagrant」ユーザーを作成しておく。 インストール後

```bash
yum -y update
yum -y groupinstall "Development Tools"
yum -y install curl
sed -i 's/^SELINUX=.\*/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld
systemctl disable firewalld
rm /etc/udev/rules.d/70-persistent-ipoib.rules
yum clean alll
```

vagrant ユーザーがパスワードなしでrootでなんでも出来るようにする requiretty もコメントアウト

```
visudo
```

「デバイス」→「Guest Additions CD イメージの挿入...」を選択後 メニューが表示されない場合は「右Ctrl」+「Home」

```bash
mount -r /dev/cdrom /mnt
cd /mnt
sh VBoxLinuxAdditions.run
cd
umount /mnt
```

umount したらデバイスからCDを削除しておく(eject)

```bash
mkdir ~vagrant/.ssh
chmod 755 ~vagrant/.ssh
curl -o ~vagrant/.ssh/authorized\_keys https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
chmod 644 ~vagrant/.ssh/authorized\_keys
chown -R vagrant:vagrant ~vagrant
```

後は sshd\_config いじって公開鍵認証だけにするとか、root での ssh ログインを許可しないとか不要なログを削除しておくとか。

```
shutdown -h now
```

```
vagrant package --base centos7 package.box
vagrant box add --name centos7 package.box
```

box ファイルとして追加されていることを確認

```
vagrant box list
```

package.box はもう不要なので削除

```
rm package.box
```

vagrant で起動してみる

```
vagrant init centos7
vagrant up
```
