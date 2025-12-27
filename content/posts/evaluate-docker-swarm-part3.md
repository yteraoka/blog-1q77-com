---
title: 'Docker Swarm を試す – その3'
date: Thu, 17 Mar 2016 15:48:43 +0000
draft: false
tags: ['Docker', 'Swarm']
---

[Docker Swarm を試す – その１](/2016/03/evaluate-docker-swarm-part1/) で swarm の agent の join はどうやって manager (master?) を探しているのだろう？マルチキャスト？と書いた部分ですが [Docker Swarm Discovery https://docs.docker.com/swarm/discovery/](https://docs.docker.com/swarm/discovery/#docker-hub-as-a-hosted-discovery-service) に書いてありました。 「Docker Hub as a hosted discovery service」 だったようです。Docker Hub で提供されているサービスを利用していたのでした。 `swarm create` がこのサービスで使う token を発行コマンドだったのです。 Hosted discovery service はインターネット越しでのアクセスにもなるしテスト用なので Production 環境では [libkv](https://github.com/docker/libkv) がサポートする [consul](https://www.consul.io/), [etcd](https://coreos.com/etcd/), [zookeeper](https://zookeeper.apache.org/) を使いましょうということのようです。 create で得た共通の token を使ってクラスタのリストが管理されているのでした。
