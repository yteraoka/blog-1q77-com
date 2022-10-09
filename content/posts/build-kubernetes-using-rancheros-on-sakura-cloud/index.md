---
title: 'さくらのクラウドRancherOSでKubernetes環境を構築'
date: Mon, 01 May 2017 13:44:55 +0000
draft: false
tags: ['Kubernetes', 'Rancher', 'sacloud']
---

「[さくらのクラウドで提供されたRancherOSを試す](/2017/04/rancheros-on-sacloud/)」の続きです。[Rancher](http://rancher.com/) で [Kubernetes](https://kubernetes.io/) 環境を作ってアプリをデプロイしてみます。

### Rancher Server セットアップ

Kubernetes 環境を構築するためのテストなの Rancher Server は冗長化などは考えず

```
docker run -d --restart=unless-stopped -p 8080:8080 rancher/server
```

で起動させます。 起動したらまずは画面上部の「`ADMIN`」→「`Access Control`」で認証設定を行います。Active Directory とか LDAP とか GitHub などを使えますがテストなので「`Local Authentication`」で。

### Kubernetes Environment 追加

Rancher は1つのサーバーで複数の Docker クラスタ(Orchestration)を管理することができ、クラスタ毎にアクセス権の管理ができたりします。クラスタ化も Rancher 独自の Cattle の他、ここで試す Kubernetes や Docker Swarm、Mesos にも対応しておりそれぞれを簡単に構築することが可能です。 左上の「`Default`」（デフォルトの Environment 名）と表示されているメニューから「`Manage Environments`」にアクセスします。「`Add Environment`」ボタンから作成画面へ移動し、「`Environment Template`」で「`Kubernetes`」を選択して任意の名前を入力して「`Create`」ボタンをクリックするだけで準備完了です。今回は「`k8s`」という名前にしました。後は、この環境にホストを追加すれば Kubernetes 環境ができてしまいます。 また「`Default`」のメニューから今作成した「`k8s`」を選択することで環境を切り替えます。 「Setting up Kubernetes」と表示され何やらセットアップが進んでる風に見えますが、進みません。上部に

> Before adding your first service or launching a container, you'll need to add a Linux host with a [supported version](http://docs.rancher.com/rancher/v1.5/en/hosts/#supported-docker-versions) or Docker. Add a host

と表示されており、`Add a host` のリンクからホストを追加する必要があります。

### Kubernetes 用サーバーのセットアップ

[前回](/2017/04/rancheros-on-sacloud/) と同じように RancherOS イメージを使って 2CPU, 2GB メモリのサーバーを3台起動させます。Rancher Server と通信できる必要がありますし、構築するサービスに外部からアクセスするのに別途 Load Balancer などを使わないのであればインターネットに接続させます。 k8s-01, k8s-02, k8s-03 というサーバーをセットアップしました。

### RancherOS の更新

前回試さなかったのですが `ros` コマンドで OS の更新ができます。

```
$ sudo ros os
NAME:
   ros os - operating system upgrade/downgrade

USAGE:
   ros os command [arguments...]

COMMANDS:
     upgrade  upgrade to latest version
     list     list the current available versions
     version  show the currently installed version
```

更新可能なバージョンが無いかと確認してみると

```
$ sudo ros os list
rancher/os:v1.0.1 remote latest 
rancher/os:v1.0.0 remote available running
rancher/os:v0.9.2 remote available 
rancher/os:v0.9.1 remote available 
...snip...
```

`v1.0.1` が存在するようなので更新してみます。

```
$ sudo ros os upgrade
Upgrading to rancher/os:v1.0.1
Continue [y/N]: y
Pulling os-upgrade (rancher/os:v1.0.1)...
v1.0.1: Pulling from rancher/os
627beaf3eaaf: Pull complete 
56ecb7539042: Pull complete 
ab6a6aa500c0: Pull complete 
237fe36f0593: Pull complete 
959d9773a286: Pull complete 
f62d8177237f: Pull complete 
25a6fb770b97: Pull complete 
6235a630e44b: Pull complete 
fb3adec6ce09: Pull complete 
c7354f67942a: Pull complete 
Digest: sha256:6656686f65c3820a8399ec64f80b2511cc0441d9202dba445d8d4cab7dfd85e0
Status: Downloaded newer image for rancher/os:v1.0.1
os-upgrade_1 | Installing from :v1.0.1
Continue with reboot [y/N]: y
> INFO[0034] Rebooting
```

とっても簡単に更新できました。`-f` オプションをつければプロンプトも出さずに reboot して更新が完了します。

### Docker のバージョン変更

ホストを追加せよってメッセージのところに [supported version](http://docs.rancher.com/rancher/v1.5/en/hosts/#supported-docker-versions) というリンクがありました。そうです、Kubernetes はまだ最新の Docker には対応していません。 RancherOS に入っている Docker のバージョンはいくつでしょうか？

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

`17.03.1-ce` では新しすぎますね。RancherOS は Docker のバージョンも `ros` コマンドで簡単に変更できます。`sudo ros engine list` で使用可能な一覧が確認できます。

```
$ sudo ros engine list
disabled docker-1.10.3
disabled docker-1.11.2
disabled docker-1.12.6
disabled docker-1.13.1
current  docker-17.03.1-ce
disabled docker-17.04.0-ce
```

Kubernetes でサポートされているのは 1.12 までなので `docker-1.12.6` を使うように変更します。

```
$ sudo ros engine switch docker-1.12.6
> INFO[0001] Project [os]: Starting project               
> INFO[0001] [0/16] [docker]: Starting                    
Pulling docker (rancher/os-docker:1.12.6)...
1.12.6: Pulling from rancher/os-docker
52160511971f: Pull complete 
Digest: sha256:1916540f838dbef62602e0565541a3e25dcb66649369ed697266326fc3cd615c
Status: Downloaded newer image for rancher/os-docker:1.12.6
> INFO[0007] Recreating docker                            
> INFO[0008] [1/16] [docker]: Started                     
> INFO[0008] Project [os]: Project started
```

```
$ docker version
Client:
 Version:      1.12.6
 API version:  1.24
 Go version:   go1.6.4
 Git commit:   78d1802
 Built:        Wed Jan 11 00:23:16 2017
 OS/Arch:      linux/amd64

Server:
 Version:      1.12.6
 API version:  1.24
 Go version:   go1.6.4
 Git commit:   78d1802
 Built:        Wed Jan 11 00:23:16 2017
 OS/Arch:      linux/amd64
```

Docker のバージョンも簡単に切り替えることができました。それでは Rancher にホストを追加しましょう。

### Rancher の Environment にホストを追加

いよいよホストの追加です。Add a host のリンクか上部メニューの「`INFRASTRUCTURE`」→「`Hosts`」から追加します。 Rancher は認証情報を設定してやれば各クラウドサービスのAPIを使って自動で AWS EC2 や Azure VM、DigitalOcean の VPS インスタンスを起動し、Docker をインストールしホストとして組み込むところまでやってくれますが、今回は自前でセットアップした RancherOS を登録するので `Custom` を選択します。

{{< figure src="rancher-add-a-host.png" caption="Rancher add a host" >}}

IPSec のために追加するホスト同士で 500/udp, 4500/udp が開いていれば、ホストのIPアドレスを入力して（省略したら Rancher Server が接続元のIPアドレスを使う）、次のテキストエリアに表示されている docker コマンドをホストで実行するだけで完了です。

```
sudo docker run \
  -e CATTLE_AGENT_IP="{node-ip-address}" \
  --rm --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.2.2 \
  http://rancher-server/v1/scripts/7BC9F0A0ECE7DD1C2EF7:1483142400000:0gH7Zulb3WzXMgclidhtiXZ8Ag
```

こんな感じのコマンドを実行するだけ。 3台登録するとこんな感じになります。

{{< figure src="rancher-kubernetes-hosts-1.png" caption="Rancher Kubernetes Host" >}}

これは全てのコンテナの状態が緑ですが、3台起動する過程で停止して移動させたりもろもろあるので赤も混ざってきます。stop 済みの赤いコンテナは手動で削除しました。 「`INFRASTRUCTURE`」→「`Containers`」では次のような表示になります。

{{< figure src="rancher-kubernetes-containers-1.png" caption="Rancher Kubernetes Containers" >}}

ホストは `Deactivate` でそれ以上 container を起動しなくなりますが、動いていた container はそのまま残ります。`Deactivate` 状態のホストは削除することが可能です。削除されたホストで稼働していた container は必要ではれば別のホストで起動されます。ホストが3台以上になると etcd が3台構成となりますが、etcd は同一ホストで複数起動させられないため、3台未満では etcd の冗長性が担保できなくなります。

[次回は Kubernetes 上にサービスをデプロイしてみます](/2017/05/deploy-services-on-k8s-with-rancher/)
