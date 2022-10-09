---
title: 'DC/OS をセットアップしてみる'
date: Sun, 21 Aug 2016 15:05:06 +0000
draft: false
tags: ['DCOS', 'Docker', 'Mesos']
---

[https://dcos.io/docs/1.7/administration/installing/custom/advanced/](https://dcos.io/docs/1.7/administration/installing/custom/advanced/) を参考に [DC/OS](https://dcos.io/) をセットアップしてみる 環境はいつものように [DigitalOcean](https://m.do.co/c/97e74a2e7336) CoreOS で master 3台、agent 1台 別 OS で良かったのかどうかわからないけど Bootstrap 用サーバーを Ubuntu で1台

### Bootstrap サーバーのセットアップ

Bootstrap サーバーはセットアップ用のパッケージやスクリプトの配布サーバーです。 まずは Docker Engine のインストール

```
$ curl -fsSL https://get.docker.com/ | sh
```

任意の場所に genconf というディレクトリを作成

```
$ mkdir -p genconf
```

genconf/config.yaml を作成

```yaml
---
bootstrap_url: http://: cluster_name: ''
exhibitor_storage_backend: static
ip_detect_filename: /genconf/ip-detect
master_list:
- - - resolvers:
- 8.8.4.4
- 8.8.8.8 
```

<bootstrap\_public\_ip> は master, agent の各サーバーからアクセス可能な bootstrap サーバーのIPアドレス <your\_port> は任意のポート、Docker で起動する nginx の publish port です /genconf/ip-deect はこの後 genconf/ip-detect というスクリプトファイルを作成します <cluster-name> は任意のクラスタ名 resolvers の DNS サーバーも他に自前のものがあればそれでも問題なし genconf/ip-detect というファイルで自ホストのIPアドレスを取得するスクリプトを作成します DigitalOcean なので [metadata API](https://blog.1q77.com/2016/08/digitalocean-metadata-api/) から取得します

```bash
#!/bin/bash

curl -fsSL http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address
```

[DC/OS installer](https://downloads.dcos.io/dcos/EarlyAccess/commit/14509fe1e7899f439527fb39867194c7a425c771/dcos_generate_config.sh?_ga=1.109119493.1649375087.1470311624) のダウンロード

```
$ curl -O https://downloads.dcos.io/dcos/EarlyAccess/commit/14509fe1e7899f439527fb39867194c7a425c771/dcos_generate_config.sh
```

ここで dcos\_generate\_config.sh を実行します

```
$ sudo bash dcos_generate_config.sh
Extracting image from this script and loading into docker daemon, this step can take a few minutes
dcos-genconf.14509fe1e7899f4395-3a2b7e03c45cd615da.tar
c56b7dabbc7a: Loading layer [==================================================>] 5.041 MB/5.041 MB
cb9346f72a60: Loading layer [==================================================>] 22.73 MB/22.73 MB
bc3f3016e472: Loading layer [==================================================>] 4.063 MB/4.063 MB
24e0af39909a: Loading layer [==================================================>] 129.5 MB/129.5 MB
fd56668380be: Loading layer [==================================================>] 2.048 kB/2.048 kB
90755ec2374c: Loading layer [==================================================>] 415.4 MB/415.4 MB
58ae10cff6df: Loading layer [==================================================>] 4.608 kB/4.608 kB
Loaded image: mesosphere/dcos-genconf:14509fe1e7899f4395-3a2b7e03c45cd615da
Running mesosphere/dcos-genconf docker with BUILD_DIR set to /root/genconf
====> EXECUTING CONFIGURATION GENERATION
Generating configuration files...
Final arguments:{
...
}
Package filename: packages/dcos-config/dcos-config--setup_caecbbeb5649b58b74977a1adbd6512480245c9a.tar.xz
Package filename: packages/dcos-metadata/dcos-metadata--setup_caecbbeb5649b58b74977a1adbd6512480245c9a.tar.xz
Generating Bash configuration files for DC/OS
```

次のような状態となります

```
.
├── dcos-genconf.14509fe1e7899f4395-3a2b7e03c45cd615da.tar
├── dcos_generate_config.sh
└── genconf
    ├── cluster_packages.json
    ├── config.yaml
    ├── ip-detect
    ├── serve
    │   ├── bootstrap
    │   │   ├── 3a2b7e03c45cd615da8dfb1b103943894652cd71.active.json
    │   │   └── 3a2b7e03c45cd615da8dfb1b103943894652cd71.bootstrap.tar.xz
    │   ├── bootstrap.latest
    │   ├── cluster-package-info.json
    │   ├── dcos_install.sh
    │   ├── fetch_packages.sh
    │   └── packages
    │       ├── dcos-config
    │       │   └── dcos-config--setup_caecbbeb5649b58b74977a1adbd6512480245c9a.tar.xz
    │       └── dcos-metadata
    │           └── dcos-metadata--setup_caecbbeb5649b58b74977a1adbd6512480245c9a.tar.xz
    └── state

7 directories, 13 files
```

ここで genconf/serve を DocumentRoot として nginx でファイルを公開します

```
$ sudo docker run -d -p :80 -v $PWD/genconf/serve:/usr/share/nginx/html:ro nginx 
```

Bootstrap サーバーのセットアップはこれで完了

### Master サーバー3台のセットアップ

3台それぞれで実行します 作業ディレクトリの作成と移動

```
$ mkdir /tmp/dcos && cd /tmp/dcos
```

Bootstrap サーバーからセットアップ用スクリプトのダウンロード

```
$ curl -O http://:/dcos_install.sh 
```

Master サーバーとしてセットアップされるように引数に master を指定して実行

```
$ sudo bash dcos_install.sh master
```

これでしばらく待っていれば完了です 大量のサービスが登録されています

```
$ systemctl | grep dcos
dcos-adminrouter.service                                          loaded active running   Admin Router: A high performance web server and a reverse proxy server
dcos-cosmos.service                                               loaded active running   Package Service: DC/OS Packaging API
dcos-ddt.service                                                  loaded active running   Diagnostics: DC/OS Distributed Diagnostics Tool Master API and Aggregation Service
dcos-epmd.service                                                 loaded active running   Erlang Port Mapping Daemon: DC/OS Erlang Port Mapping Daemon
dcos-exhibitor.service                                            loaded active running   Exhibitor: Zookeeper Supervisor Service
dcos-history-service.service                                      loaded active running   Mesos History: DC/OS Resource Metrics History Service/API
dcos-marathon.service                                             loaded active running   Marathon: DC/OS Init System
dcos-mesos-dns.service                                            loaded active running   Mesos DNS: DNS based Service Discovery
dcos-mesos-master.service                                         loaded active running   Mesos Master: DC/OS Mesos Master Service
dcos-minuteman.service                                            loaded active running   Layer 4 Load Balancer: DC/OS Layer 4 Load Balancing Service
dcos-oauth.service                                                loaded active running   OAuth: OAuth Authentication Service
dcos-spartan.service                                              loaded active running   DNS Dispatcher: An RFC5625 Compliant DNS Forwarder
dcos.target                                                       loaded active active    dcos.target
dcos-adminrouter-reload.timer                                     loaded active waiting   Admin Router Reloader Timer: Periodically reload admin router nginx config to pickup new dns
dcos-gen-resolvconf.timer                                         loaded active waiting   Generate resolv.conf Timer: Periodically update systemd-resolved for mesos-dns
dcos-logrotate.timer                                              loaded active waiting   Logrotate Timer: Timer to trigger every 2 minutes
dcos-signal.timer                                                 loaded active waiting   Signal Timer: Timer for DC/OS Signal Service
dcos-spartan-watchdog.timer                                       loaded active waiting   DNS Dispatcher Watchdog Timer: Periodically check is Spartan is working
```

### Agent サーバーのセットアップ

Master とほぼ同じですが最後のスクリプト実行の引数が異なります

```
$ sudo bash dcos_install.sh slave
```

### Exhibitor for ZooKeeper にアクセスしてみる

Master サーバーの port 8181 で Exhibitor が起動しています

{{< figure src="Exhibitor.png" caption="Exhibitor for ZooKeeper" >}}


### DC/OS Dashboard へアクセスしてみる

Master サーバーの port 80 で DC/OS コンソールが起動しています OAuth でログインします

{{< figure src="DCOS_login.png" caption="DC/OS login" >}}

Dashboard 画面（Marathon で1つのコンテナを実行中）

{{< figure src="DCOS_Dashboard.png" caption="DC/OS Dashboard" >}}

Services 画面では Marathon が稼働していることが確認できます ここから Marathon のインターフェースにアクセスできます

{{< figure src="DCOS_Services.png" caption="DC/OS Services" >}}

Marathon のインターフェース、ここで Application として Docker コンテナなどを実行できます

{{< figure src="DCOS_Marathon.png" caption="DC/OS Marathon" >}}

Nodes では Agent ノードの状況が確認できます、ここでは1つしか Agent をセットアップしていないので1つしか見えません

{{< figure src="DCOS_Nodes.png" caption="DC/OS Nodes" >}}

Universe では簡単に（ワンクリック？）追加可能なサービスが並んでいます

{{< figure src="DCOS_Universe_Packages.png" caption="DC/OS Universe Packages" >}}

System では DC/OS を構成する各コンポーネントの状況が確認できます

{{< figure src="DCOS_System.png" caption="DC/OS System" >}}

非常に沢山のコンポーネントがあります

* Admin Router
* Admin Router Reloader
* Admin Router Reloader Timer
* Cluster ID
* Diagnostics
* DNS Dispatcher
* DNS Dispatcher Watchdog
* DNS Dispatcher Watchdog Timer
* Erlang Port Mapping Daemon
* Exhibitor
* Generate resolv.conf
* Generate resolv.conf Timer
* Keepalived
* Layer 4 Load Balancer
* Logrotate
* Logrotate Timer
* Marathon
* Mesos Agent
* Mesos DNS
* Mesos History
* Mesos Master
* Mesos Persistent Volume Discovery
* OAuth
* Package Service
* Signal
* Signal Timer

### Chronos を追加してみる

Universe の Chronos アイコンの下にある Install Package をクリックすると、確認が表示されます

{{< figure src="DCOS_chronos_confirm.png" caption="DC/OS Chronos install confirm" >}}

再度 Install Package をクリックするとインストールが始まります、これだけでインストール完了です

{{< figure src="DCOS_Chronos_success.png" caption="DC/OS Chronos install finished" >}}

しばらくすると Services に Chronos が追加されていることが確認できます

{{< figure src="DCOS_Services2.png" caption="DC/OS Services に Chronos が追加されている" >}}

とりあえず動かすことはできたが調べるべきことが盛り沢山だ
