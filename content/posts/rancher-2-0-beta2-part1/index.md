---
title: 'Rancher 2.0 beta を触ってみる - その1'
date: Mon, 09 Apr 2018 15:43:39 +0000
draft: false
tags: ['Kubernetes', 'Rancher']
---

Rancher 2.0 が beta になったそうなので試してみます [Rancher 2.0 Now Feature Complete, Enters Final Beta Phase](https://rancher.com/rancher-2-0-now-feature-complete-enters-final-beta-phase/)

{{< figure src="Rancher-2-0-Now-Feature-Complete-Enters-Final-Beta-Phase.png" >}}

2.0 のゴールはここに書かれています [Release Goals](https://github.com/rancher/rancher/wiki/Rancher-2.0#release-goals)

### 準備

[Quick Start Guide](https://rancher.com/docs/rancher/v2.0/en/quick-start-guide/) の **HOST AND NODE REQUIREMENTS** に

```
Operating System: Ubuntu 16.04 (64-bit)
Memory: 4GB
Ports: 80, 443
Software: Docker
  Supported Versions:
    1.12.6
    1.13.1
    17.03.2
```

とあるので、DigitalOcean の **One-click apps** で **Docker 17.12.0~ce on 16.04** を使って Docker のインストールされたメモリ 4GB の Ubuntu 16.04 を用意します。

```bash
doctl compute droplet create rancher20 \
  --image docker-16-04 \
  --region sgp1 \
  --size s-2vcpu-4gb \
  --ssh-keys 16797382 \
  --enable-private-networking \
  --enable-monitoring
```

```
root@rancher20:~# docker version
Client:
 Version:       17.12.0-ce
 API version:   1.35
 Go version:    go1.9.2
 Git commit:    c97c6d6
 Built: Wed Dec 27 20:11:19 2017
 OS/Arch:       linux/amd64

Server:
 Engine:
  Version:      17.12.0-ce
  API version:  1.35 (minimum version 1.12)
  Go version:   go1.9.2
  Git commit:   c97c6d6
  Built:        Wed Dec 27 20:09:53 2017
  OS/Arch:      linux/amd64
  Experimental: false
```

Docker の version がちょっと新しすぎるのかな？でもまあこのまま勧めてみよう。
(Kubernetes [v1.10 Release Notes](https://kubernetes.io/docs/imported/release/notes/) の **External Dependencies** には "The validated docker versions are the same as for v1.9: 1.11.2 to 1.13.1 and 17.03.x ([ref](https://github.com/kubernetes/kubernetes/blob/master/test/e2e_node/system/docker_validator_test.go))" とある) 後で出てきますが Kubernetes の node で使う docker はこれではなく、ちゃんと対応したバージョンを Rancher がインストールしてくれます。

ところで、いつの間にか **Container Distributions** っていう Image 種別ができてて RancherOS まで揃ってますね。

{{< figure src="digitalocean-container-distributions.png" caption="Digital Ocean の Image 選択画面" >}}


### Rancher 2.0 のインストール

QuickStart に INSTALL って書いてあるけど docker run するだけです

```
docker run -d --name rancher --restart=unless-stopped -p 80:80 -p 443:443 rancher/server:preview
```

```
root@rancher20:~# docker ps
CONTAINER ID        IMAGE                    COMMAND                  CREATED             STATUS              PORTS                                      NAMES
ed3e26b3b4b4        rancher/server:preview   "rancher --http-list…"   6 seconds ago       Up 4 seconds        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   rancher
```

### Rancher 2.0 にアクセス

サーバーの 443 ポートにアクセスすると、まず admin ユーザーのパスワードを設定せよ言われます

{{< figure src="rancher-set-admin-password.png" caption="admin ユーザーのパスワード設定" >}}

次に URL の指定です。DNS を設定したりしてたらそれを指定します。この後作る各 node からアクセスできる必要があります。

{{< figure src="rancher-server-url.png" caption="Rancher Server の URL 設定" >}}

ここからクラスタを追加します。

{{< figure src="rancher-clusters.png" caption="クラスタの追加" >}}

**Node Drivers** ページ。Amazon EC2, Azure, DigitalOcean, vSphere はデフォルトで有効になっています。これらを使うのであれば Rancher が API でアクセスして node をセットアップしてくれます。今回は DigitalOcean を使います、最初から有効になっているので特にすることは無し、Token 設定はクラスタ作成時の Node Template で行います

{{< figure src="rancher-node-drivers.png" caption="Node Driver リスト" >}}

ユーザーの作成画面です。権限を細かく指定できます。次の画面から別途 Role を作成することも可能です

{{< figure src="rancher-users.png" caption="User の作成" >}}

Security -> Roles で Role の確認ができます。このキャプチャに載っているのは一部のみ。**Add Role** から追加できます

{{< figure src="rancher-security-roles.png" caption="Role 一覧" >}}

Security -> Authentication 画面がこちら、認証プロバイダとして **Active Directory** と **GitHub** が使えるようです。LDAP は使えないのかな？
Active Directory でなんとかなるのかな？

{{< figure src="rancher-security-authentication.png" caption="認証設定" >}}

Pod の Security Policy を作成できるらしい、まだ良くわかってない

{{< figure src="rancher-security-add-policy.png" caption="Security Policy 設定画面" >}}

カタログは Helm 用の機能になったっぽい？

{{< figure src="rancher-catalogs.png" caption="カタログ" >}}

それでは DigitalOcean でクラスタの追加を行います。Kubernetes version は v1.8.10-rancher1-1, v1.9.5-rancher1-1, v1.10.0-rancher1-1 から選択できます。最新の v1.10.0 にしてみます。Network Provider は Flanel, Calico, Canal から選べます。デフォルトが [Canal](https://github.com/projectcalico/canal) になってるのでこれを使ってみます。Docker version on nodes で "Require a supported Docker version" と "Allow unsupported versions" を選択できますが、Rancher Server 用に 17.12.0-ce 使ったので "Allow unsupported versios" を選んだのですが、node 用の docker はちゃんと Rancher が適したバージョンのものを入れてくれるのでそんな必要はありませんでした。

{{< figure src="rancher-add-cluster.png" caption="クラスタの追加" >}}

Add Node Template をクリックすると DigitalOcean の Token を入力画面が出ます

{{< figure src="rancher-add-node-template1.png" caption="Node Template の追加" >}}

次にどこのリージョンにどんなスペックでホストを作るかを指定します

{{< figure src="rancher-add-node-template2.png" >}}

これでいよいよ作成できますが、etcd, Control, Worker をどの template でセットアップするか指定することもできるのでそれぞれを適したサイズのインスタンスとすることができます

{{< figure src="rancher-node-pools.png" >}}

作成をはじめました

{{< figure src="rancher-clusters2.png" >}}

作成中

{{< figure src="rancher-cluster-plgt2-1.png" >}}

作成中

{{< figure src="rancher-nodes1.png" >}}

セットアップ完了

{{< figure src="rancher-nodes2.png" >}}

Node 情報はこんな感じ

{{< figure src="rancher-node.png" caption="Node 情報" >}}

ログの送り先もいろいろ選択肢があります、Embedded Elasticsearch を選択してみました

{{< figure src="rancher-cluster-logging.png" >}}

Namespace 一覧です、cattle-system ってところに Embedded Elasticsearch 環境が作られてそうだけど pod の確認方法がまだわからん...

{{< figure src="rancher-namespaces.png" >}}

Rancher 1.x での Kubernetes 管理は Kubernetes の Dashboard をそのまま使うことになっていましたが、2.0 では Rancher の画面で全部行うっぽいです。Pod の一覧とか見る方法がまだわからんのだが kubectl で見れば良いのかな... クラスタ画面に **Launch kubectl** というボタンがあり、そこから kubectl コマンドがブラウザ上で実行できます。

```
> kubectl get pods --all-namespaces
NAMESPACE        NAME                                    READY     STATUS    RESTARTS   AGE
cattle-logging   elasticsearch-5b4dbd9c6f-qjvvx          1/1       Running   0          41m
cattle-logging   fluentd-4vzxw                           2/2       Running   0          41m
cattle-logging   fluentd-6rq4x                           2/2       Running   0          41m
cattle-logging   fluentd-kppdh                           2/2       Running   0          41m
cattle-logging   kibana-866d475695-z6t4b                 1/1       Running   0          41m
cattle-system    cattle-cluster-agent-5697cbf779-hwmxq   1/1       Running   0          48m
cattle-system    cattle-node-agent-44g8r                 1/1       Running   0          48m
cattle-system    cattle-node-agent-59tpp                 1/1       Running   0          48m
cattle-system    cattle-node-agent-xp2p7                 1/1       Running   0          48m
ingress-nginx    default-http-backend-564b9b6c5b-vjfc9   1/1       Running   0          48m
ingress-nginx    nginx-ingress-controller-7jgbr          1/1       Running   0          48m
ingress-nginx    nginx-ingress-controller-tpqmp          1/1       Running   0          48m
ingress-nginx    nginx-ingress-controller-w627f          1/1       Running   0          48m
kube-system      canal-2tpw4                             3/3       Running   0          48m
kube-system      canal-6gkch                             3/3       Running   0          48m
kube-system      canal-wm7hj                             3/3       Running   0          48m
kube-system      kube-dns-7dfdc4897f-7skjn               3/3       Running   0          48m
kube-system      kube-dns-autoscaler-6c4b786f5-2qwvm     1/1       Running   0          48m
```

Web UI では見えてなかった cattle-logging という Namespace が存在しますね、うーむ 今日はここまで。
