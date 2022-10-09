---
title: 'さくらのクラウドで提供されたRancherOSを試す'
date: Wed, 26 Apr 2017 15:22:13 +0000
draft: false
tags: ['Docker', 'Rancher']
---

2017.04.20 に [Rancher OSのアーカイブ提供を開始いたしました | さくらのクラウドニュース](http://cloud-news.sakura.ad.jp/2017/04/20/rancheros-publicarchives-release/) というニュースが出ていました。

Kubernetes を気軽に立てたり捨てたりする環境として Rancher は便利そうなので気になっていました。どの OS 使うべきか悩みますしね ([Dockerの本番運用 | インフラ・ミドルウェア | POSTD](http://postd.cc/docker-in-production-an-update/))。RancherOS は Rancher 用に最小のパッケージングで提供される OS です。そして全てを docker で実行します。ntpd も syslog も docker コンテナで稼働してます。udev や acpid なんてのもいます。

[A simplified Linux distribution built from containers, for containers](http://rancher.com/rancher-os/) RancherOS は 4/12 に GA が出たばかりです [\[Press Release\] RancherOS Hits General Availability](http://rancher.com/press-release-rancheros-ga/) [Dockerコンテナに特化した「RancherOS」正式版リリース。Linuxカーネル上でDockerを実行、システムもユーザーもすべてをコンテナ空間に － Publickey](http://www.publickey1.jp/blog/17/dockerrancheroslinuxdocker.html) ログインして `sudo system-docker ps` を実行すると OS の必要機能として起動している docker コンテナが確認できます。

```
$ sudo system-docker ps
CONTAINER ID        IMAGE                       COMMAND                  CREATED             STATUS              PORTS               NAMES
b67a69f4b088        rancher/os-docker:17.03.1   "ros user-docker"        13 minutes ago      Up 13 minutes                           docker
79a01794e57b        rancher/os-console:v1.0.0   "/usr/bin/ros entrypo"   13 minutes ago      Up 13 minutes                           console
df1815599bbf        rancher/os-base:v1.0.0      "/usr/bin/ros entrypo"   13 minutes ago      Up 13 minutes                           ntp
30b6333158ca        rancher/os-base:v1.0.0      "/usr/bin/ros entrypo"   13 minutes ago      Up 13 minutes                           network
ab5b3abf4e74        rancher/os-base:v1.0.0      "/usr/bin/ros entrypo"   13 minutes ago      Up 13 minutes                           udev
517a848c2a36        rancher/os-acpid:v1.0.0     "/usr/bin/ros entrypo"   13 minutes ago      Up 13 minutes                           acpid
79d1abc559d2        rancher/os-base:v1.0.0      "/usr/bin/ros entrypo"   13 minutes ago      Up 13 minutes                           syslog
```

`system-docker` は `/usr/bin/ros` への symbolic link で通常の docker コマンド (`/usr/bin/docker` は `/var/lib/rancher/engine/docker` への symbolic link) とは別物になっています。

### さくらのクラウドで RancherOS を起動してみる

[https://secure.sakura.ad.jp/cloud/](https://secure.sakura.ad.jp/cloud/) からログインします。 サーバーの「追加」で「2. ディスク」の「アーカイブ選択」で「`[20GB] RancherOS v1.0.0 LTS #112900470901`」を選択します。 すると次のような表示が出ます。

> 管理ユーザ名は「rancher」です。 サーバ作成後、rancherユーザでログインしてください。 \[注意事項\] サーバへの接続の際には公開鍵の登録が必須となります。 リモートコンソールからのログインは出来ません。 こちらは20GB固定サイズのアーカイブです。 20GBより大きいディスクを作成する場合、 パーティションをリサイズする cloud-config をご利用ください。 https://docs.rancher.com/os/configuration/resizing-device-partition/

これに従って「4. ディスクの修正」では「公開鍵」で「入力」か「選択」で公開鍵をセットします。 「配置する スタートアップスクリプト」は yaml\_cloud\_config しか使えません。 プリセットの「`[public] Switching Consoles for RancherOS #112900473840`」が選択できますが必要であれば自作できます。 [https://docs.rancher.com/os/configuration/](https://docs.rancher.com/os/configuration/) SSH の公開鍵登録登録の例 ([SSH Keys](https://docs.rancher.com/os/configuration/ssh-keys/))

```yaml
#cloud-config
ssh_authorized_keys:
  - ssh-rsa AAA...ZZZ example1@rancher
  - ssh-rsa BBB...ZZZ example2@rancher
```

ファイルを作成する例 ([Writing Files](https://docs.rancher.com/os/configuration/write-files/))

```yaml
#cloud-config
write_files:
  - path: /etc/rc.local
    permissions: "0755"
    owner: root
    content: |
      #!/bin/bash
      echo "I'm doing things on start"
```

コマンド実行の例 ([Running Commands](https://docs.rancher.com/os/configuration/running-commands/))

```yaml
#cloud-config
runcmd:
- [ touch, /home/rancher/test1 ]
- echo "test" > /home/rancher/test2
```

その他 IP アドレスやらいろいろ設定できます

### ros コマンド

設定変更や OS の upgrade / downgrade ができるようです

```
$ sudo ros -v
ros version v1.0.0
```

```
$ sudo ros help
NAME:
   ros - Control and configure RancherOS

USAGE:
   ros [global options] command [command options] [arguments...]
   
VERSION:
   v1.0.0
   
AUTHOR(S):
   Rancher Labs, Inc. 
   
COMMANDS:
     config, c   configure settings
     console     manage which console container is used
     engine      manage which Docker engine is used
     service, s  Command line interface for services and compose.
     os          operating system upgrade/downgrade
     tls         setup tls configuration
     install     install RancherOS to disk
     selinux     Launch SELinux tools container.
     help, h     Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --help, -h     show help
   --version, -v  print the version
```

### docker コマンドを実行してみる

```
$ docker run -p 80:80 -d nginx
Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
36a46ebd5019: Pull complete 
57168433389f: Pull complete 
332ec8285c50: Pull complete 
Digest: sha256:c15f1fb8fd55c60c72f940a76da76a5fccce2fefa0dd9b17967b9e40b0355316
Status: Downloaded newer image for nginx:latest
ce6cec3a61a7a74c071fab1a11db0f291845cb58863d1e44f3194c50c8526924
```

これで普通に port 80 で nginx にアクセスできます

### docker version

```
$ docker version
Client:
 Version:      17.03.1-ce
 API version:  1.27
 Go version:   go1.7.5
 Git commit:   c6d412e
 Built:        Tue Mar 28 00:40:02 2017
 OS/Arch:      linux/amd64

Server:
 Version:      17.03.1-ce
 API version:  1.27 (minimum version 1.12)
 Go version:   go1.7.5
 Git commit:   c6d412e
 Built:        Tue Mar 28 00:40:02 2017
 OS/Arch:      linux/amd64
 Experimental: false
```

### Rancher Server を起動してみる

とりあえずお試しなのでこれで [LAUNCHING RANCHER SERVER - SINGLE CONTAINER (NON-HA)](https://docs.rancher.com/rancher/v1.5/en/installing-rancher/installing-server/#launching-rancher-server---single-container-non-ha)

```
$ docker run -d --restart=unless-stopped -p 8080:8080 rancher/server
Unable to find image 'rancher/server:latest' locally
latest: Pulling from rancher/server
6599cadaf950: Pull complete 
23eda618d451: Pull complete 
(snip)  
58bafb65736d: Pull complete 
232b8325e66b: Pull complete 
Digest: sha256:eeeab5bd80f707e2523c11c7fa437315d56fe97113eed7ad2dc058aa26555db0
Status: Downloaded newer image for rancher/server:latest
1c45fd639bba2d07180786dd6ed95e3e6afb01d84637bf6d3c75db312301d672
```

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                              NAMES
1c45fd639bba        rancher/server      "/usr/bin/entry /u..."   47 seconds ago      Up 46 seconds       3306/tcp, 0.0.0.0:8080->8080/tcp   upbeat_elion
```

起動しました。port 8080 でアクセスできました。
起動してしまえば後は過去記事と同じ

- [DigitalOcean にて Rancher を試す – その1](/2017/01/rancher-on-digitalocean-part1/)
- [DigitalOcean にて Rancher を試す – その2 (HA構成)](/2017/01/rancher-on-digitalocean-part2/)

### クーポン

[インフラ技術を極めろ！クラウドマスター認定試験｜teratail（テラテイル）](https://teratail.com/sakura-cloud) でいただいた **20,000円分のクーポン** を使わせていただいております。ありがとうございます。
ちなみにこのブログでも頻繁に登場する DigitalOcean については [http://docs.rancher.com/os/running-rancheros/cloud/do/](http://docs.rancher.com/os/running-rancheros/cloud/do/) に「Running RancherOS on DigitalOcean is not yet supported.」と書いてありました。

### 次回

次回は RancherOS で Kubernetes Environment を作ってみます。
