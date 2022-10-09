---
title: 'Rancher 2.0 の HA 構成を試す'
date: Sun, 13 May 2018 15:11:32 +0000
draft: false
tags: ['Kubernetes', "Let's Encrypt", 'Rancher', 'Lego']
---

Beta を試すシリーズ（[その1](/2018/04/rancher-2-0-beta2-part1/)、[その2](/2018/04/rancher-2-0-beta-part2/)）を書いていましたがついに 5月1日に Rancher 2.0 が GA になりました [Announcing Rancher 2.0 GA!](https://rancher.com/blog/2018/2018-05-01-rancher-ga-announcement-sheng-liang/) (Docker Hub にある image の tag はまだ `preview` でした)

今回は High Availability 構成をどうやって構築するかを確認してみます

[High Availability Installation](https://rancher.com/docs/rancher/v2.x/en/installation/ha-server-install/)

にドキュメントがあります。

Rancher 1.x では Rancher server + MySQL という構成で、MySQL をなんらかの方法で冗長構成として Rancher server を単純に複数用意すれば良かった（[DigitalOcean にて Rancher を試す – その2 (HA構成)](/2017/01/rancher-on-digitalocean-part2/)）のですが、Rancher 2.0 では Kubernetes に Rancher server を deploy するということになっています。Kubernetes を管理する Rancher を別の Kubernetes に入れないと行けないというのは gcc を gcc でコンパイルする的な感じで？？

さて、Rancher を使えば簡単に構築できる Kubernetes をどうやって構築するのか？[先日試した](/2018/04/create-kubernetes-using-kubeadm/) [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/) か？ いいえ、RKE (Rancher Kubernetes Engine) というものがあるようです

[An Introduction To Rancher Kubernetes Engine (RKE)](https://rancher.com/an-introduction-to-rke/)

次のような構成を作るみたいです。Rancher server は1個だけで kubernetes による healthcheck と再起動頼みってことでしょうか。内蔵 etcd のデータはどうなるんだろう？

![](https://rancher.com/docs/img/rancher/ha/rancher2ha.svg)

それでは手順にそって進めてみましょう。今回も [DigitalOcean](https://m.do.co/c/97e74a2e7336) で試します。サブドメイン切って DigitalOcean でレコード管理することにしてみました。これは無料らしい。 クライアント環境は Windows ですが、コマンドは go 製ばかりだし git-bash で作業してるのでほぼ Linux でも mac でも同じかな。

### ドメインを決めて SSL/TLS 署名書を用意する

[Let's Encrypt](https://letsencrypt.org/) で証明書を取得します DigitalOcean で管理しているドメインで、サーバー3台にインストールするので [ACME の DNS-01](https://tools.ietf.org/html/draft-ietf-acme-acme-01) が簡単に使える [lego](https://github.com/xenolf/lego) を使います。（[lego についての過去の投稿](/2016/07/auto-update-certificate-with-lego/)）

```
$ curl -LO https://github.com/xenolf/lego/releases/download/v0.4.1/lego_windows_amd64.zip
$ unzip lego_windows_amd64.zip
$ mv lego_windows_amd64.exe ~/bin/lego
```

DigitalOcean の DNS レコードをいじるために DO\_AUTH\_TOKEN 環境変数に API Token をセットする必要があります

```
$ export DO_AUTH_TOKEN=0123456789abcdef0123456789abcdef012346789abcdef012346789abcdef01
$ lego --domains rancher.mydomain.example.com --email メールアドレス --accept-tos --dns digitalocean run
```

これで .lego/certificates/ ディレクトリに DOMAIN.crt, DOMAIN.issuer.crt, DOMAIN.json, DOMAIN.key が作成されます

### Docker 入りの Ubuntu 16.04 を 3 台用意する

Kubernetes でサポートされている Docker をインストールするスクリプトを user-data として渡します

```
$ cat > userdata.txt <<EOD
#!/bin/bash
curl https://releases.rancher.com/install-docker/17.03.sh | sh
EOD

$ for i in 1 2 3; do
  doctl compute droplet create rke-node${i} \
    --image ubuntu-16-04-x64 \
    --region sgp1 \
    --size s-1vcpu-2gb \
    --ssh-keys 16797382 \
    --user-data-file userdata.txt \
    --enable-monitoring
done
```

```
$ doctl compute droplet list
ID          Name         Public IPv4       Private IPv4    Public IPv6    Memory    VCPUs    Disk    Region    Image                 Status    Tags    Features      Volumes
93518929    rke-node1    188.166.xxx.111                                  2048      1        50      sgp1      Ubuntu 16.04.4 x64    active            monitoring
93518934    rke-node2    188.166.xxx.222                                  2048      1        50      sgp1      Ubuntu 16.04.4 x64    active            monitoring
93518938    rke-node3    188.166.xxx.333                                  2048      1        50      sgp1      Ubuntu 16.04.4 x64    active            monitoring
```

### DNS 登録

3台の node の IP アドレスを rancher.mydomain.example.com として登録します

```
$ doctl compute domain records create mydomain.example.com --record-name rancher --record-type A --record-data 188.166.xxx.111 --record-ttl 300
$ doctl compute domain records create mydomain.example.com --record-name rancher --record-type A --record-data 188.166.xxx.222 --record-ttl 300
$ doctl compute domain records create mydomain.example.com --record-name rancher --record-type A --record-data 188.166.xxx.333 --record-ttl 300
```

list コマンドで確認します

```
$ doctl compute domain records list mydomain.example.com
```

### rke バイナリのダウンロード

[github.com/rancher/rke](https://github.com/rancher/rke) の [releases](https://github.com/rancher/rke/releases) ページからバイナリをダウンロードします

```
curl -Lo ~/bin/rke https://github.com/rancher/rke/releases/download/v0.1.7-rc2/rke_windows-amd64.exe
```

```
$ rke -version
rke version v0.1.7-rc2
```

### Template のダウンロード

rke 用のテンプレートをダウンロードします。自己署名の証明書を使うか、公の証明機関の証明書を使うかによって2種類あります。今回は Let's Encrypt を使うので `3-node-certificate-recognizedca.yml` の方を使います

* [Template for using Self Signed Certificate (3-node-certificate.yml)](https://raw.githubusercontent.com/rancher/rancher/master/rke-templates/3-node-certificate.yml)
* [Template for using Certificate Signed By A Recognized Certificate Authority (3-node-certificate-recognizedca.yml)](https://raw.githubusercontent.com/rancher/rancher/master/rke-templates/3-node-certificate-recognizedca.yml)

テンプレートなので必要な箇所を置換する必要があります

#### Nodes セクションの置換

`nodes` にある `<IP>` を各サーバーの IP アドレスに、`<USER>` を ssh でログインするユーザー名（DigitalOcean ではデフォルトが `root`）、`<SSHKEY_FILE>` を ssh に使う private key のファイル（一般的には `~/.ssh/id_rsa` かな）に置換します

#### 証明書の置換

```
$ cat .lego/certificates/rancher.mydomain.example.com.crt .lego/certificates/rancher.mydomain.example.com.issuer.crt > crt.pem
$ base64 -w 0 crt.pem
```

で `<BASE64_CRT>` を

```
$ base64 -w 0 .lego/certificates/rancher.mydomain.example.com.key
```

で `<BASE64_KEY>` を置換します

#### FQDN の置換

`<FQDN>` を rancher.mydomain.example.com に置換します。2箇所あります。

### rke コマンドの実行

```
$ rke up --config 3-node-certificate-recognizedca.yml
```

```
$ rke up --config 3-node-certificate-recognizedca.yml
time="2018-05-13T22:46:38+09:00" level=info msg="Building Kubernetes cluster"
time="2018-05-13T22:46:38+09:00" level=info msg="[dialer] Setup tunnel for host [188.166.xxx.111]"
time="2018-05-13T22:46:39+09:00" level=info msg="[dialer] Setup tunnel for host [188.166.xxx.222]"
time="2018-05-13T22:46:41+09:00" level=info msg="[dialer] Setup tunnel for host [188.166.xxx.333]"
time="2018-05-13T22:46:42+09:00" level=info msg="[network] Deploying port listener containers"
time="2018-05-13T22:46:42+09:00" level=info msg="[network] Pulling image [rancher/rke-tools:v0.1.6] on host [188.166.xxx.222]"
time="2018-05-13T22:46:42+09:00" level=info msg="[network] Pulling image [rancher/rke-tools:v0.1.6] on host [188.166.xxx.333]"
time="2018-05-13T22:46:42+09:00" level=info msg="[network] Pulling image [rancher/rke-tools:v0.1.6] on host [188.166.xxx.111]"
time="2018-05-13T22:47:01+09:00" level=info msg="[network] Successfully pulled image [rancher/rke-tools:v0.1.6] on host [188.166.xxx.222]"
time="2018-05-13T22:47:01+09:00" level=info msg="[network] Successfully pulled image [rancher/rke-tools:v0.1.6] on host [188.166.xxx.111]"
time="2018-05-13T22:47:01+09:00" level=info msg="[network] Successfully pulled image [rancher/rke-tools:v0.1.6] on host [188.166.xxx.333]"
time="2018-05-13T22:47:01+09:00" level=info msg="[network] Successfully started [rke-etcd-port-listener] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:02+09:00" level=info msg="[network] Successfully started [rke-etcd-port-listener] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:02+09:00" level=info msg="[network] Successfully started [rke-etcd-port-listener] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:03+09:00" level=info msg="[network] Successfully started [rke-cp-port-listener] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:03+09:00" level=info msg="[network] Successfully started [rke-cp-port-listener] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:03+09:00" level=info msg="[network] Successfully started [rke-cp-port-listener] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:03+09:00" level=info msg="[network] Successfully started [rke-worker-port-listener] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:03+09:00" level=info msg="[network] Successfully started [rke-worker-port-listener] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:04+09:00" level=info msg="[network] Successfully started [rke-worker-port-listener] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:04+09:00" level=info msg="[network] Port listener containers deployed successfully"
time="2018-05-13T22:47:04+09:00" level=info msg="[network] Running etcd <-> etcd port checks"
time="2018-05-13T22:47:04+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:04+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:05+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:05+09:00" level=info msg="[network] Running control plane -> etcd port checks"
time="2018-05-13T22:47:05+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:06+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:06+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:06+09:00" level=info msg="[network] Running control plane -> worker port checks"
time="2018-05-13T22:47:07+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:07+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:07+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:07+09:00" level=info msg="[network] Running workers -> control plane port checks"
time="2018-05-13T22:47:08+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:08+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:08+09:00" level=info msg="[network] Successfully started [rke-port-checker] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:08+09:00" level=info msg="[network] Checking KubeAPI port Control Plane hosts"
time="2018-05-13T22:47:08+09:00" level=info msg="[network] Removing port listener containers"
time="2018-05-13T22:47:09+09:00" level=info msg="[remove/rke-etcd-port-listener] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:47:09+09:00" level=info msg="[remove/rke-etcd-port-listener] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:47:09+09:00" level=info msg="[remove/rke-etcd-port-listener] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:47:09+09:00" level=info msg="[remove/rke-cp-port-listener] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:47:09+09:00" level=info msg="[remove/rke-cp-port-listener] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:47:09+09:00" level=info msg="[remove/rke-cp-port-listener] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:47:10+09:00" level=info msg="[remove/rke-worker-port-listener] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:47:10+09:00" level=info msg="[remove/rke-worker-port-listener] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:47:10+09:00" level=info msg="[remove/rke-worker-port-listener] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:47:10+09:00" level=info msg="[network] Port listener containers removed successfully"
time="2018-05-13T22:47:10+09:00" level=info msg="[certificates] Attempting to recover certificates from backup on [etcd] hosts"
time="2018-05-13T22:47:11+09:00" level=info msg="[certificates] Successfully started [cert-fetcher] container on host [188.166.xxx.111]"
time="2018-05-13T22:47:11+09:00" level=info msg="[certificates] Successfully started [cert-fetcher] container on host [188.166.xxx.222]"
time="2018-05-13T22:47:13+09:00" level=info msg="[certificates] Successfully started [cert-fetcher] container on host [188.166.xxx.333]"
time="2018-05-13T22:47:13+09:00" level=info msg="[certificates] No Certificate backup found on [etcd] hosts"
time="2018-05-13T22:47:13+09:00" level=info msg="[certificates] Generating CA kubernetes certificates"
time="2018-05-13T22:47:13+09:00" level=info msg="[certificates] Generating Kubernetes API server certificates"
time="2018-05-13T22:47:14+09:00" level=info msg="[certificates] Generating Kube Controller certificates"
time="2018-05-13T22:47:14+09:00" level=info msg="[certificates] Generating Kube Scheduler certificates"
time="2018-05-13T22:47:15+09:00" level=info msg="[certificates] Generating Kube Proxy certificates"
time="2018-05-13T22:47:16+09:00" level=info msg="[certificates] Generating Node certificate"
time="2018-05-13T22:47:16+09:00" level=info msg="[certificates] Generating admin certificates and kubeconfig"
time="2018-05-13T22:47:17+09:00" level=info msg="[certificates] Generating etcd-188.166.xxx.111 certificate and key"
time="2018-05-13T22:47:18+09:00" level=info msg="[certificates] Generating etcd-188.166.xxx.222 certificate and key"
time="2018-05-13T22:47:18+09:00" level=info msg="[certificates] Generating etcd-188.166.xxx.333 certificate and key"
time="2018-05-13T22:47:18+09:00" level=info msg="[certificates] Temporarily saving certs to [etcd] hosts"
time="2018-05-13T22:47:25+09:00" level=info msg="[certificates] Saved certs to [etcd] hosts"
time="2018-05-13T22:47:25+09:00" level=info msg="[reconcile] Reconciling cluster state"
time="2018-05-13T22:47:25+09:00" level=info msg="[reconcile] This is newly generated cluster"
time="2018-05-13T22:47:25+09:00" level=info msg="[certificates] Deploying kubernetes certificates to Cluster nodes"
time="2018-05-13T22:47:32+09:00" level=info msg="Successfully Deployed local admin kubeconfig at [./kube_config_3-node-certificate-recognizedca.yml]"
time="2018-05-13T22:47:32+09:00" level=info msg="[certificates] Successfully deployed kubernetes certificates to Cluster nodes"
time="2018-05-13T22:47:32+09:00" level=info msg="Pre-pulling kubernetes images"
time="2018-05-13T22:47:32+09:00" level=info msg="[pre-deploy] Pulling image [rancher/hyperkube:v1.10.1-rancher2] on host [188.166.xxx.222]"
time="2018-05-13T22:47:32+09:00" level=info msg="[pre-deploy] Pulling image [rancher/hyperkube:v1.10.1-rancher2] on host [188.166.xxx.333]"
time="2018-05-13T22:47:32+09:00" level=info msg="[pre-deploy] Pulling image [rancher/hyperkube:v1.10.1-rancher2] on host [188.166.xxx.111]"
time="2018-05-13T22:48:21+09:00" level=info msg="[pre-deploy] Successfully pulled image [rancher/hyperkube:v1.10.1-rancher2] on host [188.166.xxx.111]"
time="2018-05-13T22:48:24+09:00" level=info msg="[pre-deploy] Successfully pulled image [rancher/hyperkube:v1.10.1-rancher2] on host [188.166.xxx.222]"
time="2018-05-13T22:48:34+09:00" level=info msg="[pre-deploy] Successfully pulled image [rancher/hyperkube:v1.10.1-rancher2] on host [188.166.xxx.333]"
time="2018-05-13T22:48:34+09:00" level=info msg="Kubernetes images pulled successfully"
time="2018-05-13T22:48:34+09:00" level=info msg="[etcd] Building up etcd plane.."
time="2018-05-13T22:48:34+09:00" level=info msg="[etcd] Pulling image [rancher/coreos-etcd:v3.1.12] on host [188.166.xxx.111]"
time="2018-05-13T22:48:40+09:00" level=info msg="[etcd] Successfully pulled image [rancher/coreos-etcd:v3.1.12] on host [188.166.xxx.111]"
time="2018-05-13T22:48:40+09:00" level=info msg="[etcd] Successfully started [etcd] container on host [188.166.xxx.111]"
time="2018-05-13T22:48:41+09:00" level=info msg="[etcd] Successfully started [rke-log-linker] container on host [188.166.xxx.111]"
time="2018-05-13T22:48:41+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:48:42+09:00" level=info msg="[etcd] Pulling image [rancher/coreos-etcd:v3.1.12] on host [188.166.xxx.222]"
time="2018-05-13T22:48:48+09:00" level=info msg="[etcd] Successfully pulled image [rancher/coreos-etcd:v3.1.12] on host [188.166.xxx.222]"
time="2018-05-13T22:48:48+09:00" level=info msg="[etcd] Successfully started [etcd] container on host [188.166.xxx.222]"
time="2018-05-13T22:48:49+09:00" level=info msg="[etcd] Successfully started [rke-log-linker] container on host [188.166.xxx.222]"
time="2018-05-13T22:48:49+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:48:50+09:00" level=info msg="[etcd] Pulling image [rancher/coreos-etcd:v3.1.12] on host [188.166.xxx.333]"
time="2018-05-13T22:48:56+09:00" level=info msg="[etcd] Successfully pulled image [rancher/coreos-etcd:v3.1.12] on host [188.166.xxx.333]"
time="2018-05-13T22:48:56+09:00" level=info msg="[etcd] Successfully started [etcd] container on host [188.166.xxx.333]"
time="2018-05-13T22:48:57+09:00" level=info msg="[etcd] Successfully started [rke-log-linker] container on host [188.166.xxx.333]"
time="2018-05-13T22:48:57+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:48:57+09:00" level=info msg="[etcd] Successfully started etcd plane.."
time="2018-05-13T22:48:57+09:00" level=info msg="[controlplane] Building up Controller Plane.."
time="2018-05-13T22:48:58+09:00" level=info msg="[controlplane] Successfully started [kube-apiserver] container on host [188.166.xxx.111]"
time="2018-05-13T22:48:58+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-apiserver] on host [188.166.xxx.111]"
time="2018-05-13T22:48:58+09:00" level=info msg="[controlplane] Successfully started [kube-apiserver] container on host [188.166.xxx.222]"
time="2018-05-13T22:48:58+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-apiserver] on host [188.166.xxx.222]"
time="2018-05-13T22:48:58+09:00" level=info msg="[controlplane] Successfully started [kube-apiserver] container on host [188.166.xxx.333]"
time="2018-05-13T22:48:58+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-apiserver] on host [188.166.xxx.333]"
time="2018-05-13T22:49:15+09:00" level=info msg="[healthcheck] service [kube-apiserver] on host [188.166.xxx.111] is healthy"
time="2018-05-13T22:49:15+09:00" level=info msg="[healthcheck] service [kube-apiserver] on host [188.166.xxx.222] is healthy"
time="2018-05-13T22:49:16+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:16+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:49:16+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:16+09:00" level=info msg="[controlplane] Successfully started [kube-controller-manager] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:16+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-controller-manager] on host [188.166.xxx.111]"
time="2018-05-13T22:49:17+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:49:17+09:00" level=info msg="[controlplane] Successfully started [kube-controller-manager] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:17+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-controller-manager] on host [188.166.xxx.222]"
time="2018-05-13T22:49:17+09:00" level=info msg="[healthcheck] service [kube-controller-manager] on host [188.166.xxx.111] is healthy"
time="2018-05-13T22:49:18+09:00" level=info msg="[healthcheck] service [kube-apiserver] on host [188.166.xxx.333] is healthy"
time="2018-05-13T22:49:18+09:00" level=info msg="[healthcheck] service [kube-controller-manager] on host [188.166.xxx.222] is healthy"
time="2018-05-13T22:49:18+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:18+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:19+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:49:19+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:49:19+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:19+09:00" level=info msg="[controlplane] Successfully started [kube-scheduler] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:19+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-scheduler] on host [188.166.xxx.111]"
time="2018-05-13T22:49:19+09:00" level=info msg="[controlplane] Successfully started [kube-controller-manager] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:19+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-controller-manager] on host [188.166.xxx.333]"
time="2018-05-13T22:49:19+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:49:20+09:00" level=info msg="[controlplane] Successfully started [kube-scheduler] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:20+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-scheduler] on host [188.166.xxx.222]"
time="2018-05-13T22:49:20+09:00" level=info msg="[healthcheck] service [kube-scheduler] on host [188.166.xxx.111] is healthy"
time="2018-05-13T22:49:20+09:00" level=info msg="[healthcheck] service [kube-controller-manager] on host [188.166.xxx.333] is healthy"
time="2018-05-13T22:49:21+09:00" level=info msg="[healthcheck] service [kube-scheduler] on host [188.166.xxx.222] is healthy"
time="2018-05-13T22:49:21+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:21+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:22+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:49:22+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:49:22+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:22+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:49:22+09:00" level=info msg="[controlplane] Successfully started [kube-scheduler] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:22+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-scheduler] on host [188.166.xxx.333]"
time="2018-05-13T22:49:23+09:00" level=info msg="[healthcheck] service [kube-scheduler] on host [188.166.xxx.333] is healthy"
time="2018-05-13T22:49:24+09:00" level=info msg="[controlplane] Successfully started [rke-log-linker] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:24+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:49:24+09:00" level=info msg="[controlplane] Successfully started Controller Plane.."
time="2018-05-13T22:49:24+09:00" level=info msg="[authz] Creating rke-job-deployer ServiceAccount"
time="2018-05-13T22:49:25+09:00" level=info msg="[authz] rke-job-deployer ServiceAccount created successfully"
time="2018-05-13T22:49:25+09:00" level=info msg="[authz] Creating system:node ClusterRoleBinding"
time="2018-05-13T22:49:25+09:00" level=info msg="[authz] system:node ClusterRoleBinding created successfully"
time="2018-05-13T22:49:25+09:00" level=info msg="[certificates] Save kubernetes certificates as secrets"
time="2018-05-13T22:49:26+09:00" level=info msg="[certificates] Successfully saved certificates as kubernetes secret [k8s-certs]"
time="2018-05-13T22:49:26+09:00" level=info msg="[state] Saving cluster state to Kubernetes"
time="2018-05-13T22:49:26+09:00" level=info msg="[state] Successfully Saved cluster state to Kubernetes ConfigMap: cluster-state"
time="2018-05-13T22:49:26+09:00" level=info msg="[worker] Building up Worker Plane.."
time="2018-05-13T22:49:27+09:00" level=info msg="[sidekick] Sidekick container already created on host [188.166.xxx.222]"
time="2018-05-13T22:49:27+09:00" level=info msg="[sidekick] Sidekick container already created on host [188.166.xxx.111]"
time="2018-05-13T22:49:27+09:00" level=info msg="[sidekick] Sidekick container already created on host [188.166.xxx.333]"
time="2018-05-13T22:49:27+09:00" level=info msg="[worker] Successfully started [kubelet] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:27+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kubelet] on host [188.166.xxx.111]"
time="2018-05-13T22:49:27+09:00" level=info msg="[worker] Successfully started [kubelet] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:27+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kubelet] on host [188.166.xxx.222]"
time="2018-05-13T22:49:27+09:00" level=info msg="[worker] Successfully started [kubelet] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:27+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kubelet] on host [188.166.xxx.333]"
time="2018-05-13T22:49:34+09:00" level=info msg="[healthcheck] service [kubelet] on host [188.166.xxx.111] is healthy"
time="2018-05-13T22:49:34+09:00" level=info msg="[healthcheck] service [kubelet] on host [188.166.xxx.222] is healthy"
time="2018-05-13T22:49:34+09:00" level=info msg="[healthcheck] service [kubelet] on host [188.166.xxx.333] is healthy"
time="2018-05-13T22:49:35+09:00" level=info msg="[worker] Successfully started [rke-log-linker] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:35+09:00" level=info msg="[worker] Successfully started [rke-log-linker] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:35+09:00" level=info msg="[worker] Successfully started [rke-log-linker] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:36+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:49:36+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:49:36+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:49:36+09:00" level=info msg="[worker] Successfully started [kube-proxy] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:36+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-proxy] on host [188.166.xxx.222]"
time="2018-05-13T22:49:36+09:00" level=info msg="[worker] Successfully started [kube-proxy] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:36+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-proxy] on host [188.166.xxx.111]"
time="2018-05-13T22:49:36+09:00" level=info msg="[worker] Successfully started [kube-proxy] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:36+09:00" level=info msg="[healthcheck] Start Healthcheck on service [kube-proxy] on host [188.166.xxx.333]"
time="2018-05-13T22:49:37+09:00" level=info msg="[healthcheck] service [kube-proxy] on host [188.166.xxx.111] is healthy"
time="2018-05-13T22:49:37+09:00" level=info msg="[healthcheck] service [kube-proxy] on host [188.166.xxx.222] is healthy"
time="2018-05-13T22:49:38+09:00" level=info msg="[healthcheck] service [kube-proxy] on host [188.166.xxx.333] is healthy"
time="2018-05-13T22:49:38+09:00" level=info msg="[worker] Successfully started [rke-log-linker] container on host [188.166.xxx.222]"
time="2018-05-13T22:49:38+09:00" level=info msg="[worker] Successfully started [rke-log-linker] container on host [188.166.xxx.111]"
time="2018-05-13T22:49:38+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.222]"
time="2018-05-13T22:49:38+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.111]"
time="2018-05-13T22:49:38+09:00" level=info msg="[worker] Successfully started [rke-log-linker] container on host [188.166.xxx.333]"
time="2018-05-13T22:49:39+09:00" level=info msg="[remove/rke-log-linker] Successfully removed container on host [188.166.xxx.333]"
time="2018-05-13T22:49:39+09:00" level=info msg="[worker] Successfully started Worker Plane.."
time="2018-05-13T22:49:39+09:00" level=info msg="[sync] Syncing nodes Labels and Taints"
time="2018-05-13T22:49:41+09:00" level=info msg="[sync] Successfully synced nodes Labels and Taints"
time="2018-05-13T22:49:41+09:00" level=info msg="[network] Setting up network plugin: canal"
time="2018-05-13T22:49:41+09:00" level=info msg="[addons] Saving addon ConfigMap to Kubernetes"
time="2018-05-13T22:49:41+09:00" level=info msg="[addons] Successfully Saved addon to Kubernetes ConfigMap: rke-network-plugin"
time="2018-05-13T22:49:41+09:00" level=info msg="[addons] Executing deploy job.."
time="2018-05-13T22:49:51+09:00" level=info msg="[addons] Setting up KubeDNS"
time="2018-05-13T22:49:51+09:00" level=info msg="[addons] Saving addon ConfigMap to Kubernetes"
time="2018-05-13T22:49:52+09:00" level=info msg="[addons] Successfully Saved addon to Kubernetes ConfigMap: rke-kubedns-addon"
time="2018-05-13T22:49:52+09:00" level=info msg="[addons] Executing deploy job.."
time="2018-05-13T22:49:57+09:00" level=info msg="[addons] KubeDNS deployed successfully.."
time="2018-05-13T22:49:57+09:00" level=info msg="[ingress] Setting up nginx ingress controller"
time="2018-05-13T22:49:57+09:00" level=info msg="[addons] Saving addon ConfigMap to Kubernetes"
time="2018-05-13T22:49:57+09:00" level=info msg="[addons] Successfully Saved addon to Kubernetes ConfigMap: rke-ingress-controller"
time="2018-05-13T22:49:57+09:00" level=info msg="[addons] Executing deploy job.."
time="2018-05-13T22:50:08+09:00" level=info msg="[ingress] ingress controller nginx is successfully deployed"
time="2018-05-13T22:50:08+09:00" level=info msg="[addons] Setting up user addons"
time="2018-05-13T22:50:08+09:00" level=info msg="[addons] Saving addon ConfigMap to Kubernetes"
time="2018-05-13T22:50:08+09:00" level=info msg="[addons] Successfully Saved addon to Kubernetes ConfigMap: rke-user-addon"
time="2018-05-13T22:50:08+09:00" level=info msg="[addons] Executing deploy job.."
time="2018-05-13T22:50:13+09:00" level=info msg="[addons] User addons deployed successfully"
time="2018-05-13T22:50:13+09:00" level=info msg="Finished building Kubernetes cluster successfully"
```

### ブラウザで Rancher にアクセス

`Finished building Kubernetes cluster successfully` なので Rancher の Web UI にアクセスできるはずですが...

`"503 Service Temporarily Unavailable"` ありゃ？？

サーバーにログインして docker logs してみると

```
Incorrect Usage. flag provided but not defined: -advertise-address

NAME:
   rancher - A new cli application

USAGE:
   rancher [global options] command [command options] [arguments...]

VERSION:
   v2.0.0

COMMANDS:
     help, h  Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --kubeconfig value         Kube config for accessing k8s cluster [$KUBECONFIG]
   --debug                    Enable debug logs
   --add-local value          Add local cluster (true, false, auto) (default: "auto")
   --http-listen-port value   HTTP listen port (default: 8080)
   --https-listen-port value  HTTPS listen port (default: 8443)
   --k8s-mode value           Mode to run or access k8s API server for management API (embedded, external, auto) (default: "auto")
   --log-format value         Log formatter used (json, text, simple) (default: "simple")
   --acme-domain value        Domain to register with LetsEncrypt
   --help, -h                 show help
   --version, -v              print the version
```

なんでじゃ？rancher コマンドに `--advertise-address` オプションなんてないはずなのに...

`3-node-certificate-recognizedca.yml`

```yaml
  kind: Deployment
  apiVersion: extensions/v1beta1
  metadata:
    namespace: cattle-system
    name: cattle
  spec:
    replicas: 1
    template:
      metadata:
        labels:
          app: cattle
      spec:
        serviceAccountName: cattle-admin
        containers:
        - image: rancher/rancher:latest
          imagePullPolicy: Always
          name: cattle-server
          ports:
          - containerPort: 80
            protocol: TCP
          - containerPort: 443
            protocol: TCP
          args:
          - --advertise-address=$(POD_IP)
          env:
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP
```

うむむ、、つい21時間前に master に変更が入っている

[https://github.com/rancher/rancher/commit/29bd33528aa810001b89580a654dddb1c53b2d6a#diff-7ddfb3e035b42cd70649cc33393fe32c](https://github.com/rancher/rancher/commit/29bd33528aa810001b89580a654dddb1c53b2d6a#diff-7ddfb3e035b42cd70649cc33393fe32c) [https://github.com/rancher/rancher/issues/13292](https://github.com/rancher/rancher/issues/13292)

2.0 に取り込まれたらまた試してみよう

merge の3日後に revert されているので 5/17 以降は使えるようになっています。

### kubectl で RKE にアクセスしてみる

`rke` コマンドで作った Kubernetes にアクセスするための `kubectl` 用ファイルが `kube_config_3-node-certificate-recognizedca.yml` としてカレントディレクトリに作成されていましたので `~/.kube/config` にコピーします

```
$ cp kube_config_3-node-certificate-recognizedca.yml ~/.kube/config
```

```
$ kubectl get nodes
NAME             STATUS    ROLES                      AGE       VERSION
188.166.xxx.111  Ready     controlplane,etcd,worker   26m       v1.10.1
188.166.xxx.222  Ready     controlplane,etcd,worker   26m       v1.10.1
188.166.xxx.333  Ready     controlplane,etcd,worker   26m       v1.10.1
```

```
$ kubectl get pods --all-namespaces
NAMESPACE       NAME                                      READY     STATUS             RESTARTS   AGE
cattle-system   cattle-95fc8b5fc-xbtm4                    0/1       CrashLoopBackOff   11         34m
ingress-nginx   default-http-backend-564b9b6c5b-lpd75     1/1       Running            0          34m
ingress-nginx   nginx-ingress-controller-2hbtq            1/1       Running            0          34m
ingress-nginx   nginx-ingress-controller-kjs7q            1/1       Running            0          34m
ingress-nginx   nginx-ingress-controller-qc5r6            1/1       Running            0          34m
kube-system     canal-gszp9                               3/3       Running            0          34m
kube-system     canal-ktg7w                               3/3       Running            0          34m
kube-system     canal-ltspx                               3/3       Running            0          34m
kube-system     kube-dns-5ccb66df65-q7wj9                 3/3       Running            0          34m
kube-system     kube-dns-autoscaler-6c4b786f5-gsskl       1/1       Running            0          34m
kube-system     rke-ingress-controller-deploy-job-qjd9h   0/1       Completed          0          34m
kube-system     rke-kubedns-addon-deploy-job-rq4w5        0/1       Completed          0          34m
kube-system     rke-network-plugin-deploy-job-wmclj       0/1       Completed          0          34m
kube-system     rke-user-addon-deploy-job-959n6           0/1       Completed          0          34m
```

以上、HA 構成のセットアップ手順でした。。。

非 HA 構成（docker run するだけ）だと Rancher がデータを保持する etcd は内蔵されていて /var/lib/rancher/etcd 配下にデータファイルが置かれているのだけれど HA 構成の場合にどうなるのか確認したかったのだけどまた後日確認だな

「[続 Rancher 2.0 の HA 構成を試す](/2018/05/rancher-2-0-ha-install-using-terraform-and-rke/)」に続きがあります
