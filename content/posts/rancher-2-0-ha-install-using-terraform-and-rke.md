---
title: '続 Rancher 2.0 の HA 構成を試す'
date: Sat, 26 May 2018 13:48:10 +0000
draft: false
tags: ['DigitalOcean', 'Kubernetes', "Let's Encrypt", 'Rancher', 'Terraform', 'Lego']
---

[前回](/2018/05/rancher-2-0-ha-install/)、運悪く起動しないタイミングで試してしまった Rancher server の HA セットアップですが、その後、当該変更が [Revert](https://github.com/rancher/rancher/commit/78c48ec05da817c2249c9ccd910c2ce71c823369) されていたので再度試せばうまくいきそうです。で、ただ同じことを繰り返しても面白くないので [Terraform](https://www.terraform.io/) の [DigitalOcean Provider](https://www.terraform.io/docs/providers/do/index.html) を使って構築してみます。

コードは [GitHub](https://github.com/yteraoka/rancher-ha-tf-do) に置いてあります。1コマンドで簡単に構築・削除できます。

[Rancher 2.0 リリースパーティ (Rancher Meetup Tokyo #12)](https://rancherjp.connpass.com/event/81796/) で @yamamoto-febc さんが [RKE Provider](https://github.com/yamamoto-febc/terraform-provider-rke) を作ったと発表されていました。気になりますが今回は shell script で rke コマンドを使いました。

### Prerequisite

* [DigitalOcean](https://m.do.co/c/97e74a2e7336) のアカウント
* 独自ドメインを所有しており、DigitalOcean の DNS サービスに zone 登録（サブドメインでも可）
* Terraform （[tfenv](https://github.com/tfutils/tfenv) 推奨、下に手順を書いてあります）
* [jq](https://stedolan.github.io/jq/) コマンド

rancher.yourdomain.example.com という名前で DNS 登録と Let's Encrypt での証明書取得も行うため、ドメインが必要です。[lego](https://github.com/xenolf/lego) というコマンドで dns-01 で証明書取得するため DigitalOcean の DNS サービスへの登録が必要です。（lego はもっと[沢山の DNS サービスに対応](https://github.com/xenolf/lego/tree/master/providers/dns)していますし、もちろん http-01, tls-sni-01 にも対応しています）

### tfenv のインストール

Terraform は version によって結構差があるのでプロジェクトごとに簡単に切り替えられるように [tfenv](https://github.com/tfutils/tfenv) を使います

```
$ git clone https://github.com/tfutils/tfenv.git ~/.tfenv
$ echo 'PATH=~/.tfenv/bin:$PATH' >> ~/.bash_profile
```

```
$ tfenv install latest
[INFO] Installing Terraform v0.11.7
[INFO] Downloading release tarball from https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_windows_amd64.zip
######################################################################## 100.0%
[INFO] Downloading SHA hash file from https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_SHA256SUMS
tfenv: tfenv-install: [WARN] No keybase install found, skipping GPG signature verification
Archive:  tfenv_download.kdvWNs/terraform_0.11.7_windows_amd64.zip
  inflating: /c/Users/ytera/.tfenv/versions/0.11.7/terraform.exe
[INFO] Installation of terraform v0.11.7 successful
[INFO] Switching to v0.11.7
[INFO] Switching completed

$ terraform version
Terraform v0.11.7

$ echo 0.11.7 > .terraform-version
```

### git clone

```
$ git clone https://github.com/yteraoka/rancher-ha-tf-do.git
$ cd rancher-ha-tf-do
```

### 環境変数設定

```
$ export DIGITALOCEAN_TOKEN=***
$ export DOMAIN_SUFFIX=yourdomain.example.com
$ export CERT_EMAIL=user@example.com
```

`DIGITALOCEAN_TOKEN`

DigitalOcean の Writable な API Token ([API ページ](https://cloud.digitalocean.com/settings/api/tokens)で取得できます）

`DOMAIN_SUFFIX`

DigitalOcean の DNS サービスに設定したドメイン名、この前に `rancher.` をつけた FQDN で rancher にアクセスすることになる

`CERT_EMAIL`

Let's Encrypt での証明書取得時に指定するメールアドレス、期限切れ通知が送られてくる

全部必須です

### 実行

あとは `./make.sh up` と実行するだけです。

```
$ ./make.sh up

```

中で実行されること

*   SSH 用の key pair 作成（作成するサーバーへのログインに使います）
*   terraform init
*   terraform plan & apply
    *   SSH の public key を登録
    *   3 つの Ubuntu サーバー（droplet）を作成（docker 17.03 をインストール）
    *   作成したサーバーのIPアドレスで DNS レコードを作成
*   lego コマンドのダウンロード
*   lego で証明書の取得
*   rke コマンドのダウンロード
*   rke コマンドの設定ファイルテンプレート [3-node-certificate-recognizedca.yml](https://raw.githubusercontent.com/rancher/rancher/master/rke-templates/3-node-certificate-recognizedca.yml) のダウンロード
*   テンプレート内の必要な箇所を置換
    *   サーバーのIPアドレスを terraform output から取得して置換
    *   SSH のユーザー名（DigitalOcean は root）
    *   FQDN
    *   サーバー証明書、秘密鍵の Base64 文字列
*   rke up コマンドの実行

### 削除

`make.sh destroy` で `terraform destroy` を実行することでサーバーとDNSレコードを削除します

```
$ ./make.sh destroy

```

`make.sh cleanup` で `lego`, `rke` バイナリや `lego` で取得した証明書なども削除します

```
$ ./make.sh cleanup

```

### kubectl でのアクセス

`rke` コマンドによって `kube_config_rke.yml` が生成されているので、これを `~/.kube/config` にコピーすることで `kubectl` コマンドでアクセスできます

[kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/) で複数のクラスタにアクセスする場合は [kubectx](https://github.com/ahmetb/kubectx) が便利そう（Windows の git-bash で使えるかな？）

#### Pod 一覧の確認

```
$ kubectl get pods --all-namespaces
NAMESPACE       NAME                                      READY     STATUS      RESTARTS   AGE
cattle-system   cattle-84f9cd8589-5k88b                   1/1       Running     0          4m
cattle-system   cattle-cluster-agent-756f689478-t5dm5     1/1       Running     0          26s
cattle-system   cattle-node-agent-cdqxp                   1/1       Running     0          26s
cattle-system   cattle-node-agent-cgfml                   1/1       Running     0          26s
cattle-system   cattle-node-agent-wdnvn                   1/1       Running     0          26s
ingress-nginx   default-http-backend-564b9b6c5b-phsvc     1/1       Running     0          4m
ingress-nginx   nginx-ingress-controller-pdmgj            1/1       Running     0          4m
ingress-nginx   nginx-ingress-controller-pxwdd            1/1       Running     0          4m
ingress-nginx   nginx-ingress-controller-qkltb            1/1       Running     0          4m
kube-system     canal-n68nf                               3/3       Running     0          4m
kube-system     canal-twt2r                               3/3       Running     0          4m
kube-system     canal-vh876                               3/3       Running     0          4m
kube-system     kube-dns-5ccb66df65-kjz9w                 3/3       Running     0          4m
kube-system     kube-dns-autoscaler-6c4b786f5-n9gbw       1/1       Running     0          4m
kube-system     rke-ingress-controller-deploy-job-ltnf5   0/1       Completed   0          4m
kube-system     rke-kubedns-addon-deploy-job-mpnzc        0/1       Completed   0          4m
kube-system     rke-network-plugin-deploy-job-vsmb9       0/1       Completed   0          4m
kube-system     rke-user-addon-deploy-job-rf6r9           0/1       Completed   0          4m

```

#### cattle-system の daemonset

Rancher 関連は `cattle-system` というネームスペースに構築されています。各 node で実行される daemonset として `cattle-node-agent` が

```
$ kubectl get daemonsets --namespace=cattle-system
NAME                DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
cattle-node-agent   3         3         3         3            3           <none>          14m

```

#### cattle-system の deployment

deployment は Rancher サーバーの `cattle` と、この Kubernetes を rancher で管理するための `cattle-cluster-agent` が

```
$ kubectl get deployments --namespace=cattle-system
NAME                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cattle                 1         1         1            1           16m
cattle-cluster-agent   1         1         1            1           12m

```

#### cattle-system の service

service としては Rancher サーバーの `cattle` 用の `cattle-service` があります

```
$ kubectl get services --namespace=cattle-system
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
cattle-service   ClusterIP   10.43.52.123   80/TCP,443/TCP   16m 
```

#### RKE の ingress-controller

RKE で構築した Kubernetes には各 node で daemonset として nginx-ingress-controller が実行されています。この nginx-ingress-controller は Host ヘッダーの値によって Proxy 先の Service を切り替えてくれます。Rancher も指定した rancher.${DOMAIN\_SUFFIX} でアクセスすると cattle-service に forward してくれます。https でも SNI のホスト名で振り分けてくれます。

```
$ kubectl get daemonsets --namespace=ingress-nginx
NAME                       DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
nginx-ingress-controller   3         3         3         3            3           <none>          23m
```

### HA な Rancher サーバーとは？

Rancher 2.0 のコンテナを Kubernetes 内で起動し、Kubernetes の使っている etcd をデータストアとして使います。今回の RKE で構築するものでは起動後にその Kubernetes を Rancher にインポートするようになっているのでログインするとすぐにその環境にコンテナをデプロイしたりできます。

![](https://rancher.com/docs/img/rancher/ha/rancher2ha.svg)

### まとめ

HA な Rancher 2.0 環境および Kubernetes クラスタを簡単に作ったり削除したりできるようになりました。
