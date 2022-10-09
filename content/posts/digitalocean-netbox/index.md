---
title: 'DigitalOcean が公開した NetBox を使ってみる'
date: Sat, 09 Jul 2016 13:30:41 +0000
draft: false
tags: ['DigitalOcean', 'Docker']
---

**Infrastructure as a Newsletter — July 07, 2016** にて

> DO’s network engineering team created [NetBox](https://github.com/digitalocean/netbox), a tool that manages both IP address management (IPAM) and datacenter infrastructure management (DCIM).

とあったので早速試してみました。 Django と PostgreSQL で作られた IP アドレスと DataCenter のラック、サーバー、ネットワーク、電源などを管理するツールです。 NetBox の GitHub を覗いてみると [docker-compose.yml](https://github.com/digitalocean/netbox/blob/develop/docker-compose.yml) があったので早速試してみようと

```
$ curl -LO https://raw.githubusercontent.com/digitalocean/netbox/develop/docker-compose.yml
$ docker-compose up -d
```

としてみましたが

```
Pulling netbox (digitalocean/netbox:latest)...
Pulling repository docker.io/digitalocean/netbox
ERROR: Error: image digitalocean/netbox not found
```

とエラーになってしまいました。repository が private なのかな？ netbox repository には [Dockerfile](https://github.com/digitalocean/netbox/blob/develop/Dockerfile) もあったので clone して docker-compose.yml の

```
image: digitalocean/netbox
```

を

```
build: .
```

に書き換えて再度

```
$ docker-compose up -d
```

したら無事起動しました。Docker 便利！！

{{< figure src="NetBoxHome.png" caption="NetBoxHome" >}}

次のような構成になってます。

### DCIM

- Sites
  - Geographic locations
- Racks
  - Equipment racks, optionally organized by group
- Devices
  - Rack-mounted network equipment, servers, and other devices
- Connections
  - Interfaces
  - Console
  - Power

### Secrets

- Secrets
  - Sensitive data (such as passwords) which has been stored securely

### IPAM

- Aggregates
  - Top-level IP allocations
- Prefixes
  - IPv4 and IPv6 network assignments
- IP Addresses
  - Individual IPv4 and IPv6 addresses
- VLANs
  - Layer two domains, identified by VLAN ID

### Circuits

- Providers
  - Organizations which provide circuit connectivity
- Circuits
  - Communication links for Internet transit, peering, and other services

できることはだいたい [racktables](http://RackTables.org/) と同じ感じです。

{{< figure src="RackTablesHome.png" caption="TackTablesHome" >}}

Site (DataCenter) があり、そこに Rack を並べ、Device (サーバーやストレージ、スイッチなど) を配置します。Device にはネットワークなどのインターフェースを登録し、それがどの Device のどのポートと接続されてるかも管理できます。（全部登録するのは結構面倒...）

RackTables を使ってるならわざわざ乗り換える必要は無い感じですかね。個人的にはデザインは NetBox の方が好きです。Device はロールごとに色を設定できるのでラックのマウント状況を確認する画面が見やすかったりもしますね。

何ができるのか試していませんが [https://github.com/digitalocean/go-netbox](https://github.com/digitalocean/go-netbox) という golang で書かれた API クライアントがあるのは便利かもしれません。

RackTables にも [https://github.com/xing/racktables\_api](https://github.com/xing/racktables_api) とかあるみたいですけど。

RackTables は PHP と MySQL のシステムです。PHP + MySQL か Python (Django) + PostgreSQL かというのも選定ポイントかな。
