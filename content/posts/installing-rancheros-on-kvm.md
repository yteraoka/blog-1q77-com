---
title: 'KVMゲストとしてRancherOSをインストール'
date: Sat, 13 May 2017 15:10:28 +0000
draft: false
tags: ['KVM', 'RancherOS']
---

### CD Boot

virt-install で ISO ファイルから仮想ゲストを作成＆起動します

```
$ virt-install \
  --name rancher \
  --vcpus 1 \
  --cpu host \
  --memory 2048,maxmemory=4096 \
  --os-variant virtio26 \
  --cdrom rancheros.iso \
  --network network=default,model=virtio \
  --disk pool=ytera,size=10,format=qcow2,bus=virtio \
  --graphics none
```

storage pool 使ったことなかったので使ってみた。

```
$ virsh pool-list
 Name                 State      Autostart 
-------------------------------------------
 default              active     yes       
 Downloads            active     yes       
 tmp                  active     yes       
 ytera                active     yes
```

```
$ virsh net-list
 Name                 State      Autostart     Persistent
----------------------------------------------------------
 default              active     yes           yes
```

### インストール

`ros install` コマンドでディスクにインストールします

```
$ sudo ros help install
NAME:
   ros install - install RancherOS to disk

USAGE:
   ros install [command options] [arguments...]

OPTIONS:
   --image value, -i value         install from a certain image (e.g., 'rancher/os:v0.7.0')
                                               use 'ros os list' to see what versions are available.
   --install-type value, -t value  generic:    (Default) Creates 1 ext4 partition and installs RancherOS (syslinux)
                        amazon-ebs: Installs RancherOS and sets up PV-GRUB
                        gptsyslinux: partition and format disk (gpt), then install RancherOS and setup Syslinux
   --cloud-config value, -c value  cloud-config yml file - needed for SSH authorized keys
   --device value, -d value        storage device
   --partition value, -p value     partition to install to
   --statedir value                install to rancher.state.directory
   --force, -f                     [ DANGEROUS! Data loss can happen ] partition/format without prompting
   --no-reboot                     do not reboot after install
   --append value, -a value        append additional kernel parameters
   --kexec, -k                     reboot using kexec
   --debug                         Run installer with debug output
```

SSH でログインするために公開鍵を cloud-config で設定する必要があります。最小でこの程度。

```
#cloud-config
ssh_authorized_keys:
  - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBE3YdsjZWcGkO8g0gCypD1ampRaZunb8VHJD0zzqjc8NxW+H192uOxwXSBJZQWAVY3yH5VIjKhnTdp83/swhajc=
hostname: rancher
```

cloud-config ファイルは事前にチェックできます

```
$ sudo ros config validate -i cloud-config.yml
```

YAML フォーマットの正しさだじゃなくて typo などの不明な設定も見つけてくれます

```
$ sudo ros config validate -i cloud-config.yml 
> ERRO[0000] hogehoge: Additional property hogehoge is not allowed
```

cloud-config で設定可能なリストは [ドキュメント](http://docs.rancher.com/os/configuration/#cloud-config) で。[ネットワーク設定](http://docs.rancher.com/os/networking/interfaces/) で固定IPにしたり bonding や Tag VLAN 設定もできます。 インストールするバージョンを `-i rancher/os:v1.0.1` などと指定できます。指定可能なリストは `ros os list` で確認できます。

```
$ sudo ros os list
rancher/os:v1.0.1 remote latest running
rancher/os:v1.0.0 remote available 
rancher/os:v0.9.2 remote available 
rancher/os:v0.9.1 remote available 
rancher/os:v0.9.0 remote available 
(snip)
```

インストールの実行。なぜか `Continue [y/N]:` へのキーボードからの入力が効かなかったので `yes` コマンドで渡して逃げました。

```
$ yes | sudo ros install -d /dev/vda -c cloud-config.yml -a "console=tty0 console=ttyS0,115200n8"
> INFO[0000] No install type specified...defaulting to generic 
Installing from rancher/os:v1.0.1
Continue [y/N]: 
> INFO[0000] start !isoinstallerloaded                    
> INFO[0000] trying to load /bootiso/rancheros/installer.tar.gz 
23b9c7b43573: Loading layer  4.23 MB/4.23 MB
f90562450ed7: Loading layer 14.96 MB/14.96 MB
94dbf06f5a27: Loading layer 4.608 kB/4.608 kB
52125c070e5e: Loading layer 18.08 MB/18.08 MB
051a95b6eaa9: Loading layer 1.636 MB/1.636 MB
a6fd95b21434: Loading layer 1.536 kB/1.536 kB
c52e27553689: Loading layer  2.56 kB/2.56 kB
7b425eeedf72: Loading layer 3.072 kB/3.072 kB
> INFO[0003] Loaded images from /bootiso/rancheros/installer.tar.gz 
> INFO[0003] starting installer container for rancher/os-installer:latest (new) 
Installing from rancher/os-installer:latest
mount: /dev/sr0 is write-protected, mounting read-only
Continue with reboot [y/N]: 
> INFO[0005] Rebooting
```

起動しました。 😊

```
> INFO[0009] [15/16] [docker]: Started                    
> INFO[0010] [16/16] [preload-user-images]: Started       
> INFO[0010] Project [os]: Project started                
> INFO[0011] RancherOS v1.0.1 started                     


               ,        , ______                 _                 _____ _____TM
  ,------------|'------'| | ___ \               | |               /  _  /  ___|
 / .           '-'    |-  | |_/ /__ _ _ __   ___| |__   ___ _ __  | | | \ '--.
 \/|             |    |   |    // _' | '_ \ / __| '_ \ / _ \ '__' | | | |'--. \
   |   .________.'----'   | |\ \ (_| | | | | (__| | | |  __/ |    | \_/ /\__/ /
   |   |        |   |     \_| \_\__,_|_| |_|\___|_| |_|\___|_|     \___/\____/
   \___/        \___/     Linux 4.9.24-rancher

         RancherOS v1.0.1 rancher ttyS0
         docker-sys: 172.18.42.2 eth0: 192.168.122.129 lo: 127.0.0.1
rancher login:
```

```
ssh rancher@192.168.122.129
```

でログインできます。 インストール先のディスクが AWS EBS や GPT の場合は `ros install` に `-t` で type の指定が必要。

### 仮想サーバーの削除

お掃除

```
$ virsh destroy rancher
$ virsh undefine rancher --remove-all-storage
Domain rancher has been undefined
Volume 'vda'(/home/ytera/rancher.qcow2) removed.
```
