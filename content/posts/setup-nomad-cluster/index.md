---
title: 'Nomad cluster のセットアップ'
date: Sun, 14 Apr 2019 15:10:59 +0000
draft: false
tags: ['Consul', 'Hashicorp', 'Nomad', 'Nomad']
---

口にするとマサカリならぬ船のホイールが飛んできそうですが、[話題](https://matthias-endler.de/2019/maybe-you-dont-need-kubernetes/)の [Hashicorp Nomad](https://www.nomadproject.io/) のクラスタをセットアップしてみました。下の図のような構成です。3台のサーバーで構築した Consul クラスタとこれまた3台のサーバーで Nomad のサーバークラスタを構築し、そこへ3台の Nomad クライアント(worker)を参加させます。公式の図を拝借したらこうなっていたのですが、Nomad サーバーとクライアントが特定のもの同士で紐づいているように見えますがそういうわけではなく、クライアントはクラスタに対して参加しています。[DigitalOcean](https://m.do.co/c/97e74a2e7336) に簡単に構築するための Terraform & Ansible を [https://github.com/yteraoka/nomad-cluster-do](https://github.com/yteraoka/nomad-cluster-do) に置いてあります。

[![](http://158.101.138.193/wp-content/uploads/2019/04/nomad-reference-diagram.png)](http://158.101.138.193/wp-content/uploads/2019/04/nomad-reference-diagram.png)

Nomad は Kubernetes の Cluster IP みたいなものがなく、コンテナの公開するポート情報を [Consul](https://www.consul.io/) に登録し、その Consul の情報を元に動的に振り分け先を更新するロードバランサー（[Fabio](https://github.com/fabiolb/fabio) というのが Consul を直接参照できるらしいし、HAProxy は 1.8 から DNS を使った動的更新ができ、この DNS サーバーとして Consul も使えるらしい）を使ったり [consul-template](https://github.com/hashicorp/consul-template) で動的に [HAProxy](http://www.haproxy.org/) や [nginx](http://nginx.org/) の設定を更新することによってサービスを公開するようにします。これは昔 (Docker 1.11 以前) の Docker Swarm の構成に似ています (参考: [小さく始める Docker container の deploy](https://www.slideshare.net/yteraoka1/docker-container-deploy))。もちろん、そんな昔のやつより高機能です。ちゃんと指定したコンテナの数を維持してくれたり、ローリングアップデートの仕組みもありますし、DaemonSet みたいなものも、batch 実行にも対応しています。Job についてはまだ詳しく見れていないけれど batch が不要なら Nomad よりも [Docker Swarm mode](https://docs.docker.com/engine/swarm/swarm-mode/) のほうが構築はずっと楽です。Docker だけで構築できますし。

[Load Balancing Strategies for Consul](https://www.hashicorp.com/blog/load-balancing-strategies-for-consul)

### Consul Cluster

Consul は3台のサーバーでクラスタを組み、Nomad を実行する各サーバー (Server も Worker も) には agent を起動させてクラスタに参加させます。各 Nomad は localhost の Consul agent とやり取りすることになります。Consul サーバーに誰でも自由にアクセスできては困るので TLS のクライアント証明書で認証するようにしてあります。Web UI へのアクセスにもクライアント証明書が必要なのでブラウザで使えるように登録します。いつの間にか consul には tls サブコマンドが実装されており、簡単に CA や証明書を作成することができるようになっていました。便利。([Creating and Configuring TLS Certificates](https://learn.hashicorp.com/consul/advanced/day-1-operations/certificates))

通信内容の暗号化だけであれば encrypt 設定があり、TLS が無効でも暗号化することができます。

Consul には ACL 機能もありますが、まだ理解不足なので有効にしていません。

TLS 認証必須にするとサーバー上で consul コマンドで確認するときにも証明書や鍵の path や URL 指定が必要でこれをいちいちコマンドラインオプションで指定するのは大変なので環境変数を使うと便利です。

```
# consul members
Error retrieving members: Get http://127.0.0.1:8500/v1/agent/members?segment=_all: dial tcp 127.0.0.1:8500: connect: connection refused
```

```bash
export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
export CONSUL_CACERT=/etc/consul.d/ca.pem
export CONSUL_CLIENT_CERT=/etc/consul.d/cert.pem
export CONSUL_CLIENT_KEY=/etc/consul.d/key.pem
```

```
# consul members
Node            Address             Status  Type    Build  Protocol  DC   Segment
consul-0        10.130.22.70:8301   alive   server  1.4.4  2         dc1  consul-1        10.130.83.30:8301   alive   server  1.4.4  2         dc1  consul-2        10.130.53.222:8301  alive   server  1.4.4  2         dc1  nomad-client-0  10.130.76.121:8301  alive   client  1.4.4  2         dc1  nomad-client-1  10.130.90.138:8301  alive   client  1.4.4  2         dc1  nomad-client-2  10.130.83.99:8301   alive   client  1.4.4  2         dc1  nomad-server-0  10.130.90.148:8301  alive   client  1.4.4  2         dc1  nomad-server-1  10.130.90.224:8301  alive   client  1.4.4  2         dc1  nomad-server-2  10.130.82.224:8301  alive   client  1.4.4  2         dc1 
```

Consul の Web UI は次のような感じ (consul サーバーの 8501 ポートに https でアクセスします)

{{< figure src="consul-ui-services.png" caption="サービス一覧" >}}

{{< figure src="consul-ui-nodes.png" caption="ノード一覧" >}}

### Nomad

Nomad も Consul と似たような構成ですね。中で Serf が使われてるのも同じですし。Consul と同じように TLS のクライアント証明書認証をするようにしました。今回構築したものは Nomad のテスト用だから当然ですが Consul は Nomad 専用なので同じ CA と証明書を使いまわすことにしました。TLS なしでの暗号化についても Consul と同じです。

Nomad も TLS のクライアント証明書認証を強制している場合は環境変数を指定しておく。nomad daemon 用には設定ファイルで指定してある。consul も同様。

```
# nomad server members
Error querying servers: Get http://127.0.0.1:4646/v1/agent/members: net/http: HTTP/1.x transport connection broken: malformed HTTP response "\x15\x03\x01\x00\x02\x02"
```

```bash
export NOMAD_ADDR=https://127.0.0.1:4646
export NOMAD_CACERT=/etc/consul.d/ca.pem
export NOMAD_CLIENT_CERT=/etc/consul.d/cert.pem
export NOMAD_CLIENT_KEY=/etc/consul.d/key.pem
```

```
# nomad server members
Name                   Address        Port  Status  Leader  Protocol  Build  Datacenter  Region
nomad-server-0.global  10.130.90.148  4648  alive   true    2         0.9.0  dc1         global
nomad-server-1.global  10.130.90.224  4648  alive   false   2         0.9.0  dc1         global
nomad-server-2.global  10.130.82.224  4648  alive   false   2         0.9.0  dc1         global

# nomad node status
ID        DC   Name            Class   Drain  Eligibility  Status
063515e8  dc1  nomad-client-2  false  eligible     ready
0977c339  dc1  nomad-client-0  false  eligible     ready
cc10bd14  dc1  nomad-client-1  false  eligible     ready 
```

Nomad の Web UI は次のような感じ (nomad サーバーの 4646 ポートに https でアクセスします)

{{< figure src="nomad-ui-servers.png" caption="サーバー一覧" >}}

{{< figure src="nomad-ui-clients.png" caption="クライアント一覧" >}}

Job はまだ登録してないので空っぽ

### Nomad は Kubernetes よりも簡単なのか？

微妙...

Overlay ネットワークとかないし、Calico, Flannel, Weave ?? どれ使えば良いの？😧 とか Istio, Cilium, Linkerd 😵 ??? という悩みは減りますね。

用途によっては Docker Swarm mode がやっぱり一番お手軽

### 続く・・・

せっかくなのでそのうち **Job** についても調べてみます。**Job** が **Deployment** で **Group** が **ReplicaSet** で **Task** が **Pod** っぽいのかな。

コンテナの実行に限らず、サーバー上のコマンドをそのまま実行したりもできる。

**Service**, **Batch**, **System** という種類があって **System** は **DaemonSet** っぽい ([Schedulers](https://www.nomadproject.io/docs/schedulers.html))
