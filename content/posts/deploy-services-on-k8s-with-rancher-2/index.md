---
title: 'RancherのKubernetesにサービスをデプロイしてみる(2)'
date: Sat, 06 May 2017 16:01:07 +0000
draft: false
tags: ['HAProxy', 'Kubernetes', 'Rancher']
---

前回「[RancherのKubernetesにサービスをデプロイしてみる](/2017/05/deploy-services-on-k8s-with-rancher/)」の続きです。

前回は [guestbook-all-in-one.yaml](https://github.com/kubernetes/kubernetes/blob/master/examples/guestbook/all-in-one/guestbook-all-in-one.yaml) の `type: LoadBalancer` をアンコメントして Rancher の Load Balancer サービスが自動で構築されるようにしてみましたが、それぞれの Pod が NodePort で外部にポートを公開する必要はないんじゃないかなということで今回はアンコメントしないでそのままデフォルトの `ClustrIP` のサービスとして構築してみます。 変更の必要がないので YAML ファイルの指定に GitHub の URL を直接使えます

```
$ kubectl create -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/examples/guestbook/all-in-one/guestbook-all-in-one.yaml
service "redis-master" created
deployment "redis-master" created
service "redis-slave" created
deployment "redis-slave" created
service "frontend" created
deployment "frontend" created
```

Deployments は前回と変わりません

{{< figure src="rancher-kubernetes-deployments.png" caption="Rancher Kubernetes Deployments" >}}

`Services` を見ると `frontend` の `External endpoints` が空っぽです

{{< figure src="rancher-kubernetes-services-no-external-ip.png" caption="Rancher Kubernetes Serivces no External endpoints" >}}

ここで Rancher の「`KUBERNETES`」→「`Infrastructure Stacks`」から「`kubernetes-ingress-lbs`」で「`Add Service`」の「`Add Load Balancer`」を選択します。

{{< figure src="kubernetes-ingress-lbs-link.png" caption="Rancher Kubernetes ingress lbs" >}}

「`Name`」を適当に入力して「`Target`」に「`frontend`」を選択して作成すれば外部からアクセス可能になります

{{< figure src="rancher-add-loadbalancer.png" caption="Rancher Add Load Balancer" >}}

「`Scale`」で任意のコンテナ数を指定可能ですが、「`Always run one instance of this container on every host`」を選択すれば全てのホストで1コンテナずつ起動されます。 この LoadBalancer は HAProxy で `Host` ヘッダーや `Path`、`Port` で proxy 先 `Service` を切替可能なのでこれ一つで複数のサービスに対応できます。Kubernetes のサービスは `ClusterIP` で作成してこの `kubernetes-ingress-lbs` で受ければ良さそうです。HAProxy からの proxy 先は1つの CLusterIP ではなく、そこに紐付いている各 Pod のです。今回の例では3つの `frontend` Pod が起動しているのでそこへ振り分けられます。HTTPS 対応も可能です、証明書は「`INFRASTRUCTURE`」→「`Certificates`」で登録したものから選択します。複数の証明書を指定可能です。

{{< figure src="rancher-loadbalancer-https.png" caption="HTTPS LoadBalancer" >}}
