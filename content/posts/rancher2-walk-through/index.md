---
title: 'Rancher2 の構築からサービス公開まで'
date: Sun, 10 Mar 2019 12:09:55 +0000
draft: false
tags: ['Kubernetes', 'Rancher']
---

Rancher 2.x の HA 構成を RKE でセットアップし、Kubernetes クラスタを追加して、その中にコンテナをデプロイし、nginx-ingress-controller 経由で外からアクセスできるようにします。

RKE での HA 構成セットアップは過去の投稿 ([続 Rancher 2.0 の HA 構成を試す](/2018/05/rancher-2-0-ha-install-using-terraform-and-rke/)) と同じです。1コマンドで構築できます。現在のところ RKE でセットアップできるのは 2.0.8 までのようでちょっと古めで、選択できる Kubernetes も 1.11.2 まで ([Hardcode Rancher version to v2.0.8 in rke templates](https://github.com/rancher/rancher/commit/e90c3c6b0a8d4a373663c04653f7974da0e88ba2#diff-96be3367763348349d37e6ffab22981a))。その後の更新はできるんじゃないかとは思うものの調べられていない。

### Kubernetes クラスタの追加

Rancher セットアップ後のクラスタ一覧画面です  
{{< figure src="cluster-list.png" caption="クラスタ一覧" >}}

ここで右上の「**Add Cluster**」ボタンから新しい Kubernetes クラスタを追加します。(すでに存在する **local** というクラスタ内で Rancher サーバーが起動しています)

クラスタ追加画面  
{{< figure src="add-cluster.png" caption="クラスタの追加" >}}

メジャーなクラウドサービスを使っている場合は認証情報を渡せばサーバーの作成から全部やってくれますが、ここでは別途 Docker のインストールされたサーバーを用意することにします。そのため一番上のアイコンが並んでいるところでは「**Custom**」を選択します。他はデフォルトのままで次に進みます。(Rancher はクラウドのマネージド Kubernetes の管理もできますし、オンプレにすでに Kubernetes が存在すればそれの管理をすることもできます。)

### Kubernetes クラスタへの Node の追加

ノードの追加コマンド確認画面  
{{< figure src="add-cluster2.png" caption="ノードの登録" >}}

まずは **etcd** と **Control Plane** 用の3台を登録します。表示されてる **docker run** コマンドをコピペすれば rancher-agent がノード内で起動して必要なことを全部やってくれます。完了までにはしばらく時間かかります。(Node Role で **Worker** にもチェックを入れておけば worker としても使えるノードとなりますが、ここでは分けることにします)

ノード一覧画面  
{{< figure src="cp-nodes.png" caption="ノード一覧(1)" >}}

Roles 列に **etcd** と **Control Plane** が入った3つのノードが確認できます。黄色い **Unschedulable** という表示はこれが Worker ノードでは無いためこのノードにコンテナが割り当てられないという意味です。

ノードの追加コマンド確認画面  
{{< figure src="add-worker-nodes.png" caption="Worker ノードの追加" >}}

次に Worker ノードを追加します。Node Role で **Worker** だけを選択してコマンドをコピペします。この環境はもう削除済みなので token もそのまま載っけちゃってますが公開しちゃダメです。

再びノード一覧画面  
{{< figure src="nodes.png" caption="ノード一覧(2)" >}}

Worker が追加されました。

クラスタのダッシュボードはこんな感じ  
{{< figure src="cluster-dashboard.png" caption="cluster dashboard" >}}

選んだサーバーの CPU 数が少なかったかな

```
$ kubectl get nodes
NAME   STATUS   ROLES               AGE   VERSION
cp1    Ready    controlplane,etcd   34m   v1.11.2
cp2    Ready    controlplane,etcd   34m   v1.11.2
cp3    Ready    controlplane,etcd   40m   v1.11.2
wk1    Ready    worker              3m    v1.11.2
wk2    Ready    worker              3m    v1.11.2
wk3    Ready    worker              3m    v1.11.2
```

### プロジェクトの作成

Rancher 2.x では Kubernetes のクラスタとネームスペースの間にプロジェクトという層が入り、複数のネームスペースを束ねて権限管理を行うことができるようになっています。このあたりも過去の[投稿](/2018/05/understanding-authentication-authorization-in-rancher-2-0/) ([Understanding Authentication & Authorization In Rancher 2.0](/2018/05/understanding-authentication-authorization-in-rancher-2-0/)) で書きました。

初期状態で **Default** と **System** というプロジェクトが存在します。  
{{< figure src="projects.png" caption="projects" >}}

自分のコンテナをデプロイするなら **Default** を使っても良さそうですが、ここでは **myproject** というプロジェクトを作ってみます。

プロジェクト追加画面  
{{< figure src="add-project.png" caption="プロジェクトの追加" >}}

クラスタ作成時に [Pod Security Policy](https://rancher.com/docs/rancher/v2.x/en/admin-settings/pod-security-policies/) を有効にするかどうか、デフォルトを何にするかという選択項目がありましたが、ここでも出てきました。コンテナに特権の付与を許可するかどうかなどを制御することができます。

### ネームスペースの作成

Kubernetes ではネームスペース単位で権限を管理し、コンテナはネームスペース内にデプロイすることになるため、新しく作ったプロジェクト内にネームスペースを作成します。

ネームスペース追加の画面  
{{< figure src="add-namespace.png" caption="ネームスペースの追加" >}}

ネームスペースの名前を指定するだけです。ここでは **myns** とします。

### ワークロードのデプロイ

Kubernetes 用語では Deployment と Service を作成することになるのかな。

デプロイ前のワークロードページ  
{{< figure src="workloads.png" caption="ワークロードページ" >}}

Deploy ボタンからワークロードをデプロイします

ワークロードをデプロイするための入力画面  
{{< figure src="deploy-workload.png" caption="ワークロードのデプロイ" >}}

名前、Docker Image、Pod の数、Port マッピング、スケーリングポリシーやボリューム、環境変数、ヘルスチェックなどを指定します。**Show advanced options** をクリックするともっと多くの項目が表示されます。Workload Type で **More options** をクリックすると DaemonSet や StatefulSet、CronJob、Job を選択できます。Port マッピングでは **NodePort (On every node)**、**HostPort (Nodes running a pod)**、**Cluster IP (Internal only)**、**Layer-4 Load Balancer** を選べます。ここでは **Cluster IP (Internal only)** を選択します。

ワークロード一覧ページ  
{{< figure src="httpbin-deployed.png" caption="Workload 一覧" >}}

今回は設定しませんが [サイドカー設定](https://rancher.com/docs/rancher/v2.x/en/k8s-in-rancher/workloads/add-a-sidecar/)はこのページの右の︙ボタンから行います。

上のキャプチャのようにして [httpbin.org](http://httpbin.org/) のコンテナをデプロイしてみました。([kennethreitz/httpbin](https://hub.docker.com/r/kennethreitz/httpbin/))  
{{< figure src="workload-httpbin.png" caption="httpbin workload" >}}

Cluster IP で作成しているのでこのままでは外部からアクセスできません

```
$ kubectl get services -n myns
NAME      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
httpbin   ClusterIP   10.43.74.133   80/TCP    16m 
```

```
$ kubectl get pods -n myns
NAME                       READY   STATUS    RESTARTS   AGE
httpbin-578b587f58-9xgwb   1/1     Running   0          16m
httpbin-578b587f58-bz27f   1/1     Running   0          16m
httpbin-578b587f58-tbnnd   1/1     Running   0          16m
```

### nginx ingress controller で外部公開する

デプロイしたコンテナに外部からアクセスできるように Workloads タブの Load Balance のページから Ingress 設定を追加します  
{{< figure src="lb-list.png" caption="Load Balancing" >}}

Ingress 設定入力ページ  
{{< figure src="add-ingress.png" caption="Ingress の追加" >}}

Hostname と Path ごとにどこに proxy するかを設定します。TLS の証明書設定も可能です。

追加後の Load Balancing 画面  
{{< figure src="lb-list2.png" caption="Load Balancing(2)" >}}

これでしばらく待つとブラウザでインターネット越しにアクセスできるようになります。

**nginx-ingress-controller** が **System** プロジェクトの **ingress-nginx** ネームスペースに **DaemonSet** として各 Worker Node にデプロイされており、Worker Node に Ingress で設定した Host ヘッダーをつけてアクセスすることで作成したコンテナにルーティングされます。

```
$ kubectl get ingress --all-namespaces
NAMESPACE   NAME      HOSTS                   ADDRESS                                      PORTS   AGE
myns        httpbin   httpbin.do.teraoka.me   178.128.24.17,178.128.24.30,206.189.94.233   80      14m
```

ブラウザで **/anything** にアクセスしました。

```json
{
  "args": {}, 
  "data": "", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8", 
    "Accept-Encoding": "gzip, deflate", 
    "Accept-Language": "ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7", 
    "Connection": "close", 
    "Host": "httpbin.do.teraoka.me", 
    "Upgrade-Insecure-Requests": "1", 
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36", 
    "X-Forwarded-Host": "httpbin.do.teraoka.me", 
    "X-Original-Uri": "/anything", 
    "X-Scheme": "http"
  }, 
  "json": null, 
  "method": "GET", 
  "origin": "我が家のグローバルIPアドレス", 
  "url": "http://httpbin.do.teraoka.me/anything"
}
```

Origin として Global IP が認識されているので X-Forwarded-For がちゃんとわたっているようです。

**YAML 一個も書いてねー！**
