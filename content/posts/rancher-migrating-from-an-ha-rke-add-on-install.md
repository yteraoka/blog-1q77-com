---
title: 'Rancher: Migrating from an HA RKE Add-on Install'
date: Sun, 24 Mar 2019 13:56:39 +0000
draft: false
tags: ['Helm', 'Kubernetes', 'Rancher', 'Rancher']
---

RKE Add-on での Rancher セットアップはもう古い
---------------------------------

過去に試していた RKE での Rancher の HA セットアップ ([続 Rancher 2.0 の HA 構成を試す](/2018/05/rancher-2-0-ha-install-using-terraform-and-rke/)) はどうやらもう古いらしい。2.0.8 までしかサポートしてないよというのには気づいていたのですが、改めてインストールページ([RKE Add-On Install](https://rancher.com/docs/rancher/v2.x/en/installation/ha/rke-add-on/))を確認するとこの方法はもう過去のものらしい。Helm 使ってねと。

> **Important: RKE add-on install is only supported up to Rancher v2.0.8**
> 
> Please use the Rancher helm chart to install HA Rancher. For details, see the [HA Install - Installation Outline](https://rancher.com/docs/rancher/v2.x/en/installation/ha/#installation-outline).
> 
> If you are currently using the RKE add-on install method, see [Migrating from an HA RKE Add-on Install](https://rancher.com/docs/rancher/v2.x/en/upgrades/upgrades/migrating-from-rke-add-on/) for details on how to move to using the helm chart.

Helm を使ったセットアップへの変更
-------------------

そんなわけで、構築済みの HA Rancher を RKE add-on から変更する手順をなぞってみます。[Migrating from an HA RKE Add-on Install](https://rancher.com/docs/rancher/v2.x/en/upgrades/upgrades/migrating-from-rke-add-on/)

### kubectl を rancher cluster に向ける

私のセットアップでは RKE に `rke.yml` というファイルを渡したので `kube_config_rke.yml` が生成されています。環境変数 `KUBECONFIG` でこれを指定します。

```
export KUBECONFIG=$(pwd)/kube\_config\_rke.yml

```

Kubernetes は 1.11.6 だったので同じバージョンの kubectl コマンドを curl で取得します。とりあえずカレントディレクトリに置いておくので以降 `./kubectl` として実行します。(後で出てくる `helm` コマンドも同様)  
[Install kubectl binary using curl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-using-curl)

次のコマンドでここまでの設定が正しく行えているかを確認します。

```
./kubectl config view -o=jsonpath='{.clusters\[\*\].cluster.server}'

```

出力が `https://NODE:6443` の様に1つのノードの 6443 ポートを指していれば正しいです。

### 証明書の保存

Rancher クラスタの Ingress で TLS Termination を行っている場合は Helm でのインストール時に必要となるため、次のコマンドで取り出します。後で Kubernetes Secrets に登録します。

証明書

```
./kubectl -n cattle-system get secret cattle-keys-ingress \\
  -o jsonpath --template='{ .data.tls\\.crt }' | base64 -d > tls.crt

```

秘密鍵

```
./kubectl -n cattle-system get secret cattle-keys-ingress \\
  -o jsonpath --template='{ .data.tls\\.key }' | base64 -d > tls.key

```

プライベート CA を使っている場合は次のコマンドで CA の証明書も取得します。

```
./kubectl -n cattle-system get secret cattle-keys-server \\
  -o jsonpath --template='{ .data.cacerts\\.pem }' | base64 -d > cacerts.pem

```

### 古い Kubernetes オブジェクトを削除

RKE でのインストールで作られた Kubernetes オブジェクトを削除する。

```
./kubectl -n cattle-system delete ingress cattle-ingress-http
./kubectl -n cattle-system delete service cattle-service
./kubectl -n cattle-system delete deployment cattle
./kubectl -n cattle-system delete clusterrolebinding cattle-crb
./kubectl -n cattle-system delete serviceaccount cattle-admin

```

これらのコンポーネントを削除しても Rancher の設定やデータベースに影響はありませんが、何かメンテナンスを行う場合にバックアップを取得しておくのは良いことです。バックアップの取得方法は [Creating Backups—High Availability Installs](https://rancher.com/docs/rancher/v2.x/en/backups/backups/ha-backups/) にあります。

### Addon の削除

RKE で使う YAML (ここでは `rke.yml`) には Rancher で必要なリソースが全て入っています。今後の RKE 操作のためにここから `addons` セクションのまるっと削除しておきます。

```
addons: |-
  ---
  kind: Namespace
  apiVersion: v1
  metadata:
    name: cattle-system
  ---
  kind: ServiceAccount
  apiVersion: v1
  metadata:
    name: cattle-admin
    namespace: cattle-system
  ---
  kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: cattle-crb
    namespace: cattle-system
  subjects:
  - kind: ServiceAccount
    name: cattle-admin
    namespace: cattle-system
  roleRef:
    kind: ClusterRole
    name: cluster-admin
    apiGroup: rbac.authorization.k8s.io
  ---
  apiVersion: v1
  kind: Secret
  metadata:
    name: cattle-keys-ingress
    namespace: cattle-system
  type: Opaque
  data:
    tls.crt: <証明書の Base64>
    tls.key: <秘密鍵の Base64>
  ---
  apiVersion: v1
  kind: Service
  metadata:
    namespace: cattle-system
    name: cattle-service
    labels:
      app: cattle
  spec:
    ports:
    - port: 80
      targetPort: 80
      protocol: TCP
      name: http
    - port: 443
      targetPort: 443
      protocol: TCP
      name: https
    selector:
      app: cattle
  ---
  apiVersion: extensions/v1beta1
  kind: Ingress
  metadata:
    namespace: cattle-system
    name: cattle-ingress-http
    annotations:
      nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "1800"   # Max time in seconds for ws to remain shell window open
      nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"   # Max time in seconds for ws to remain shell window open
  spec:
    rules:
    - host: rancher.do.teraoka.me  # FQDN to access cattle server
      http:
        paths:
        - backend:
            serviceName: cattle-service
            servicePort: 80
    tls:
    - secretName: cattle-keys-ingress
      hosts:
      - rancher.do.teraoka.me      # FQDN to access cattle server
  ---
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
        # Rancher install via RKE addons is only supported up to v2.0.8
        - image: rancher/rancher:v2.0.8
          args:
          - --no-cacerts
          imagePullPolicy: Always
          name: cattle-server
          livenessProbe:
            httpGet:
              path: /ping
              port: 80
            initialDelaySeconds: 60
            periodSeconds: 60
          readinessProbe:
            httpGet:
              path: /ping
              port: 80
            initialDelaySeconds: 20
            periodSeconds: 10
          ports:
          - containerPort: 80
            protocol: TCP
          - containerPort: 443
            protocol: TCP

```

削ると残るのはこれだけ

```
nodes:
  - address: 192.168.100.1 # hostname or IP to access nodes
    user: rancher # root user (usually 'root')
    role: \[controlplane,etcd,worker\] # K8s roles for node
    ssh\_key\_path: id\_rsa # path to PEM file
  - address: 192.168.100.2
    user: rancher
    role: \[controlplane,etcd,worker\]
    ssh\_key\_path: id\_rsa
  - address: 192.168.100.3
    user: rancher
    role: \[controlplane,etcd,worker\]
    ssh\_key\_path: id\_rsa

services:
  etcd:
    snapshot: true
    creation: 6h
    retention: 24h

```

Helm の初期化
---------

ここからは Helm を使った通常のインストールする手順 ([3\. Initialize Helm (Install Tiller)](https://rancher.com/docs/rancher/v2.x/en/installation/ha/helm-init/)) に進みます。Helm を使うためにはサーバーサイドコンポーネントの [Tiller](https://helm.sh/docs/glossary/#tiller) をインストールする必要があるようです。

`helm` コマンドは各種パッケージマネージャからもインストールできると思いますが、ここでは Github の [releases ページ](https://github.com/helm/helm/releases/latest)からダウンロードします。cert-manager との組み合わせの問題で v2.12.1 以降が必要です。

まず、`tiller` という名前で Tiller 用のサービスアカウントを作成する。

```
./kubectl -n kube-system create serviceaccount tiller

```

次に、作成したサービスアカウントに `cluster-admin` ロールを付与します。

```
./kubectl create clusterrolebinding tiller \\
  --clusterrole=cluster-admin \\
  --serviceaccount=kube-system:tiller

```

### Helm の初期化

```
./helm init --service-account tiller

```

`Tiller (the Helm server-side component) has been installed into your Kubernetes Cluster.` と表示されていれば Tiller のインストールが完了しているはず。

init 時に次のメッセージも出てました。必要であれば `--tiller-tls-verify` も付けることも検討。

> Please note: by default, Tiller is deployed with an insecure 'allow unauthenticated users' policy. To prevent this, run \`helm init\` with the --tiller-tls-verify flag. For more information on securing your installation see: https://docs.helm.sh/using\_helm/#securing-your-helm-installation

### Tiller の確認

Tiller が正しくインストールされているかどうかを次のコマンドで確かめます。

```
./kubectl -n kube-system  rollout status deploy/tiller-deploy

```

`deployment "tiller-deploy" successfully rolled out` と表示されれば OK.

バージョン確認

```
$ ./helm version
Client: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.13.1", GitCommit:"618447cbf203d147601b4b9bd7f8c37a5d39fbb4", GitTreeState:"clean"}

```

Rancher のインストール
---------------

次の手順はこちら [4\. Install Rancher](https://rancher.com/docs/rancher/v2.x/en/installation/ha/helm-rancher/).

### Helm Chart repository の追加

`latest`, `stable`, `alpha` から選んで追加します。Production 環境であれば `stable` を選択。(`alpha` は upgrade がサポートされていません)([Helm Chart Repositories](https://rancher.com/docs/rancher/v2.x/en/installation/server-tags/#helm-chart-repositories))

```
./helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

./helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

./helm repo add rancher-alpha https://releases.rancher.com/server-charts/alpha

```

### SSL/TLS 設定の選択

証明書には3つの推奨設定があります。上2つには `cert-manager` が必要。

Rancher が生成 (default)

(chart option) `ingress.tls.source=rancher`

Let's Encrypt

(chart option) `ingress.tls.source=letsEncrypt`

ファイルからの読み込み (Kubernetes の Secrets に入れる)

(chart option) `ingress.tls.source=secret`

### cert-manager のインストール (必要な場合のみ)

Kubernetes Helm chart repository からインストールする。

```
./helm install stable/cert-manager \\
  --name cert-manager \\
  --namespace kube-system \\
  --version v0.5.2

```

インストールが完了するまで待つ。次のコマンドで `deployment "cert-manager" successfully rolled out` と表示されるようになれば完了。

```
./kubectl -n kube-system rollout status deploy/cert-manager

```

### Rancher のデプロイ (Rancher Generated Certificates)

デフォルトが Rancer Generated なので特に証明書に関するオプションは指定されていない。(この例はリポジトリが `rancher-latest` になっていることに注意)

```
./helm install rancher-latest/rancher \\
  --name rancher \\
  --namespace cattle-system \\
  --set hostname=rancher.example.com

```

デプロイの状況を確認する。

```
./kubectl -n cattle-system rollout status deploy/rancher

```

### Rancher のデプロイ (Let’s Encrypt)

Let's Encrypt での証明書発行のためにメールアドレスを指定する必要がある。(この例はリポジトリが `rancher-latest` になっていることに注意)

```
./helm install rancher-latest/rancher \\
  --name rancher \\
  --namespace cattle-system \\
  --set hostname=rancher.example.com \\
  --set ingress.tls.source=letsEncrypt \\
  --set letsEncrypt.email=me@example.org

```

デプロイの状況を確認する。

```
./kubectl -n cattle-system rollout status deploy/rancher

```

### Rancher のデプロイ (Certificates from Files)

今回は RKE でのセットアップ時に使っていたものを取り出したファイルを使うのでこの手順で進めます。(この例はリポジトリが `rancher-latest` になっていることに注意)

```
./helm install rancher-latest/rancher \\
  --name rancher \\
  --namespace cattle-system \\
  --set hostname=rancher.example.com \\
  --set ingress.tls.source=secret

```

実行すると次のような出力がある。

```
NAME:   rancher
LAST DEPLOYED: Sun Mar 24 22:21:35 2019
NAMESPACE: cattle-system
STATUS: DEPLOYED

RESOURCES:
==> v1/ClusterRoleBinding
NAME     AGE
rancher  1s

==> v1/Deployment
NAME     READY  UP-TO-DATE  AVAILABLE  AGE
rancher  0/3    3           0          0s

==> v1/Pod(related)
NAME                     READY  STATUS             RESTARTS  AGE
rancher-f7467f757-9mpdp  0/1    ContainerCreating  0         0s
rancher-f7467f757-m5v49  0/1    ContainerCreating  0         0s
rancher-f7467f757-tq4jg  0/1    ContainerCreating  0         0s

==> v1/Service
NAME     TYPE       CLUSTER-IP   EXTERNAL-IP  PORT(S)  AGE
rancher  ClusterIP  10.43.23.29  80/TCP   1s

==> v1/ServiceAccount
NAME     SECRETS  AGE
rancher  1        1s

==> v1beta1/Ingress
NAME     HOSTS                ADDRESS  PORTS  AGE
rancher  rancher.example.com  80, 443  0s


NOTES:
Rancher Server has been installed.

NOTE: Rancher may take several minutes to fully initialize. Please standby while Certificates are being issued and Ingress comes up.

Check out our docs at https://rancher.com/docs/rancher/v2.x/en/

Browse to https://rancher.example.com

Happy Containering! 
```

Kubernetes Secrets に証明書を `tls` という secret タイプで `tls-rancher-ingress` という名前で登録します。

```
./kubectl -n cattle-system create secret tls tls-rancher-ingress \\
  --cert=tls.crt \\
  --key=tls.key

```

プライベート CA の場合はそれも登録する。こちらは generic タイプ。

```
./kubectl -n cattle-system create secret generic tls-ca \\
  --from-file=cacerts.pem

```

デプロイの状況を確認する。

```
./kubectl -n cattle-system rollout status deploy/rancher

```

Rancher 2.1.7 に更新されました。次は [https://github.com/yteraoka/rancher-ha-tf-do](https://github.com/yteraoka/rancher-ha-tf-do) を Helm でのセットアップに変更しようと思います。