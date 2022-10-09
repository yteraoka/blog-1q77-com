---
title: 'minikube を試す - その3'
date: Tue, 10 Jan 2017 14:00:31 +0000
draft: false
tags: ['Kubernetes']
---

[minikube を試す – その2](/2017/01/minikube-part2/) の続きです。

### デプロイメントのスケーリング

同じアプリ(Pod)を沢山並べたい時は、数を指定するだけで増減できて、異常終了などしても指定した数をキープするように再起動してくれたりするやつですね。 前回の続きなので 1 Pod だけのこの状態です。

```
$ kubectl get deployments
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1         1         1            1           19h
```

ここで表示されている **DESIRED**, **CURRENT**, **UP-TO-DATE**, **AVAILABLE** という状態はスケーリングに関係するものです。

- DESIRED
  - 望んでいる指定した Pod の数
- CURRENT
  - 現状の Pod の数
- UP-TO-DATE
  - ローリングアップデートや設定変更を行った際に更新済みとなっている Pod 数
- AVAILABLE
  - 起動処理、ヘルスチェックが完了してリクエストを受けられる状態の Pod の数

ここで **DESIRED** を 4 にしてみます。

```
$ kubectl scale deployments/kubernetes-bootcamp --replicas=4
deployment "kubernetes-bootcamp" scaled
```

1秒間隔で **kubectl get deployments** を実行してみました。 変化のあったところだけを抜き出すと次のようになっていました。

```
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1         1         1            1           19h

NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   4         4         4            1           19h

NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   4         4         4            4           19h
```

AVAILABLE になるところは時間がかかるけれども、そこまでは一瞬で進んでしまいました。 1 node であるために docker image はすでにローカルに持っているしプロセス起動するだけだからかな。

`kubectl get pods -o wide` とした方が状況が分かりやすかったです。

```
$ kubectl get pods -o wide
NAME                                  READY     STATUS    RESTARTS   AGE       IP           NODE
kubernetes-bootcamp-390780338-3tl9b   1/1       Running   0          6m        172.17.0.5   minikube
kubernetes-bootcamp-390780338-42692   1/1       Running   0          20h       172.17.0.4   minikube
kubernetes-bootcamp-390780338-6lkqt   1/1       Running   0          6m        172.17.0.6   minikube
kubernetes-bootcamp-390780338-lf295   1/1       Running   0          6m        172.17.0.7   minikube
```

`minikube ssh` して node へログインし、docker kill で pod のコンテナを止めてみたら自動で restart がかかり、**RESTARTS** の値が増えていきました。

```
$ kubectl get pods -o wide
NAME                                  READY     STATUS    RESTARTS   AGE       IP           NODE
kubernetes-bootcamp-390780338-3tl9b   1/1       Running   1          10m       minikube
kubernetes-bootcamp-390780338-42692   1/1       Running   0          20h       172.17.0.4   minikube
kubernetes-bootcamp-390780338-6lkqt   1/1       Running   2          10m       172.17.0.6   minikube
kubernetes-bootcamp-390780338-lf295   1/1       Running   1          10m       172.17.0.7   minikube 
```

リスタート直後はまだ IP が決まっておらず **"<none>"** となっています。

```
$ kubectl scale deployments/kubernetes-bootcamp --replicas=1
deployment "kubernetes-bootcamp" scaled
```

でレプリカの数を1に戻すと deployments で見える数は瞬時に 1 に戻りますが

```
$ kubectl get deployments
NAME                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1         1         1            1           20h
```

pods を確認するとしばらくは **Terminating** という状態で残っていました。

```
$ kubectl get pods -o wide
NAME                                  READY     STATUS        RESTARTS   AGE       IP           NODE
kubernetes-bootcamp-390780338-3tl9b   1/1       Terminating   2          12m       172.17.0.5   minikube
kubernetes-bootcamp-390780338-42692   1/1       Running       0          20h       172.17.0.4   minikube
kubernetes-bootcamp-390780338-6lkqt   1/1       Terminating   2          12m       172.17.0.6   minikube
kubernetes-bootcamp-390780338-lf295   1/1       Terminating   1          12m       172.17.0.7   minikube
```

数十秒後には消えます。

```
$ kubectl get pods -o wide
NAME                                  READY     STATUS    RESTARTS   AGE       IP           NODE
kubernetes-bootcamp-390780338-42692   1/1       Running   0          20h       172.17.0.4   minikube
```

### ロードバランシング

`kubectl expose` で外部からアクセスできるようにします。

```
$ kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080
service "kubernetes-bootcamp" exposed
```

```
$ kubectl describe services/kubernetes-bootcamp
Name:			kubernetes-bootcamp
Namespace:		default
Labels:			run=kubernetes-bootcamp
Selector:		run=kubernetes-bootcamp
Type:			NodePort
IP:			10.0.0.100
Port:			 8080/TCP
NodePort:		 30334/TCP
Endpoints:		172.17.0.4:8080,172.17.0.5:8080,172.17.0.6:8080 + 1 more...
Session Affinity:	None
No events. 
```

また例によって環境変数に NodePort を入れておきます

```
$ export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -o go-template='{{(index .spec.ports 0).nodePort}}')
$ echo NODE_PORT=$NODE_PORT
NODE_PORT=30334
```

kubernetes-bootcamp のアプリは **GET /** で Pod 名を返しているのでいろんな Pod に振り分けられていることがわかります。単純な Roundrobin ではなさそう。

```
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-ds1nl | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-n9pnv | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-42692 | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-n9pnv | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-42692 | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-ds1nl | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-42692 | v=1
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-n9pnv | v=1
```

`kubectl describe services/kubernetes-bootcamp` でわかるように Service の IP は **10.0.0.100** ですから `minikube ssh` で node に入って、そこから curl でアクセスすればバランシングされます。

```
docker@minikube:~$ curl 10.0.0.100:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-ds1nl | v=1
docker@minikube:~$ curl 10.0.0.100:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-42692 | v=1
docker@minikube:~$ curl 10.0.0.100:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-8mnjl | v=1
docker@minikube:~$ curl 10.0.0.100:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-8mnjl | v=1
docker@minikube:~$ curl 10.0.0.100:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-n9pnv | v=1
docker@minikube:~$ curl 10.0.0.100:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-390780338-ds1nl | v=1
```

minikube では **type=NodePort** しか使えないようですが **ClusterIP** (Default), **NodePort**, **LoadBalancer** [http://kubernetes.io/docs/user-guide/kubectl/kubectl\_expose/](http://kubernetes.io/docs/user-guide/kubectl/kubectl_expose/) expose はいろんな使い方があるようだ。

### アプリの更新

```
$ kubectl describe deployments
Name:			kubernetes-bootcamp
Namespace:		default
CreationTimestamp:	Tue, 10 Jan 2017 00:05:32 +0900
Labels:			run=kubernetes-bootcamp
Selector:		run=kubernetes-bootcamp
Replicas:		4 updated | 4 total | 4 available | 0 unavailable
StrategyType:		RollingUpdate
MinReadySeconds:	0
RollingUpdateStrategy:	1 max unavailable, 1 max surge
Conditions:
  Type		Status	Reason
  ----		------	------
  Available 	True	MinimumReplicasAvailable
OldReplicaSets:	 NewReplicaSet:	kubernetes-bootcamp-390780338 (4/4 replicas created)
No events. 
```

**RollingUpdateStrategy: 1 max unavailable, 1 max surge** とあるのでローリングアップデート時に DESIRED を 1 つ超えるだけ増やし、1 つを UNAVAILABLE にすることで許されるので 1 つ止め、追加で 1 つ新しいのを入れることで 2 つづつ置き換えていくことができます。 イメージを入れ替える v1 タグだったものを v2 に更新します

```
$ kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=jocatalin/kubernetes-bootcamp:v2
deployment "kubernetes-bootcamp" image updated
```

```
$ kubectl describe pods | grep Image:
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
```

2 個ずつ更新されてるようですね

```
$ kubectl describe pods | grep Image:
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
    Image:		docker.io/jocatalin/kubernetes-bootcamp:v1
```

古い Pod が入れ替わりました。Pod 名も変わりました。

```
 kubectl get pods
NAME                                   READY     STATUS        RESTARTS   AGE
kubernetes-bootcamp-2100875782-415gm   1/1       Running       0          25s
kubernetes-bootcamp-2100875782-l7525   1/1       Running       0          25s
kubernetes-bootcamp-2100875782-q8c18   1/1       Running       0          19s
kubernetes-bootcamp-2100875782-wgtv0   1/1       Running       0          17s
kubernetes-bootcamp-390780338-42692    1/1       Terminating   0          22h
kubernetes-bootcamp-390780338-8mnjl    1/1       Terminating   0          2h
kubernetes-bootcamp-390780338-ds1nl    1/1       Terminating   0          2h
kubernetes-bootcamp-390780338-n9pnv    1/1       Terminating   0          2h
```

Terminating はその後消えます

```
$ kubectl get pods
NAME                                   READY     STATUS    RESTARTS   AGE
kubernetes-bootcamp-2100875782-415gm   1/1       Running   0          2m
kubernetes-bootcamp-2100875782-l7525   1/1       Running   0          2m
kubernetes-bootcamp-2100875782-q8c18   1/1       Running   0          2m
kubernetes-bootcamp-2100875782-wgtv0   1/1       Running   0          2m
```

Service 経由でアクセスしてみます、v=2 が返って来てます。

```
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-2100875782-wgtv0 | v=2
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-2100875782-l7525 | v=2
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-2100875782-415gm | v=2
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-2100875782-q8c18 | v=2
$ curl $(minikube ip):$NODE_PORT
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-2100875782-415gm | v=2
```

### ロールバック

今度は v10 タグへの更新ですがこんなイメージファイルは存在しないようです

```
$ kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=jocatalin/kubernetes-bootcamp:v10
deployment "kubernetes-bootcamp" image updated
```

更新が始まりました、さきほどと同じく 1 つ停止して 2 つ追加されてます。

```
$ kubectl get pods
NAME                                   READY     STATUS              RESTARTS   AGE
kubernetes-bootcamp-1951388213-1b5q1   0/1       ContainerCreating   0          3s
kubernetes-bootcamp-1951388213-vp1tp   0/1       ContainerCreating   0          3s
kubernetes-bootcamp-2100875782-415gm   1/1       Running             0          8m
kubernetes-bootcamp-2100875782-l7525   1/1       Running             0          8m
kubernetes-bootcamp-2100875782-q8c18   1/1       Running             0          8m
kubernetes-bootcamp-2100875782-wgtv0   1/1       Terminating         0          8m
```

Image の取得に失敗してしまったようです

```
$ kubectl get pods
NAME                                   READY     STATUS         RESTARTS   AGE
kubernetes-bootcamp-1951388213-1b5q1   0/1       ErrImagePull   0          14s
kubernetes-bootcamp-1951388213-vp1tp   0/1       ErrImagePull   0          14s
kubernetes-bootcamp-2100875782-415gm   1/1       Running        0          8m
kubernetes-bootcamp-2100875782-l7525   1/1       Running        0          8m
kubernetes-bootcamp-2100875782-q8c18   1/1       Running        0          8m
kubernetes-bootcamp-2100875782-wgtv0   1/1       Terminating    0          8m
```

DESIRED が 4 で unavailable が 1 つの状態なのでこれ以上は進みません

```
$ kubectl get pods
NAME                                   READY     STATUS             RESTARTS   AGE
kubernetes-bootcamp-1951388213-1b5q1   0/1       ImagePullBackOff   0          2m
kubernetes-bootcamp-1951388213-vp1tp   0/1       ImagePullBackOff   0          2m
kubernetes-bootcamp-2100875782-415gm   1/1       Running            0          11m
kubernetes-bootcamp-2100875782-l7525   1/1       Running            0          11m
kubernetes-bootcamp-2100875782-q8c18   1/1       Running            0          11m
```

`kubectl describe pods` でログを確認

```
Events:
  FirstSeen	LastSeen	Count	From			SubObjectPath				Type	Reason		Message
  ---------	--------	-----	----			-------------				--------------		-------
  5m		5m		1	{default-scheduler }						Normal	Scheduled	Successfully assigned kubernetes-bootcamp-1951388213-1b5q1 to minikube
  5m		2m		5	{kubelet minikube}	spec.containers{kubernetes-bootcamp}	Normal	Pulling		pulling image "jocatalin/kubernetes-bootcamp:v10"
  5m		1m		5	{kubelet minikube}	spec.containers{kubernetes-bootcamp}	WarningFailed		Failed to pull image "jocatalin/kubernetes-bootcamp:v10": Tag v10 not found in repository docker.io/jocatalin/kubernetes-bootcamp
  5m		1m		5	{kubelet minikube}						WarningFailedSync	Error syncing pod, skipping: failed to "StartContainer" for "kubernetes-bootcamp" with ErrImagePull: "Tag v10 not found in repository docker.io/jocatalin/kubernetes-bootcamp"

  5m	7s	17	{kubelet minikube}	spec.containers{kubernetes-bootcamp}	Normal	BackOff		Back-off pulling image "jocatalin/kubernetes-bootcamp:v10"
  5m	7s	17	{kubelet minikube}						Warning	FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "kubernetes-bootcamp" with ImagePullBackOff: "Back-off pulling image \"jocatalin/kubernetes-bootcamp:v10\""
```

さて、にっちもさっちもいかなくなりましたので元に戻さなくてはなりません **kubectl rollout undo** で戻せるんですって

```
$ kubectl rollout undo deployments/kubernetes-bootcamp
deployment "kubernetes-bootcamp" rolled back
```

```
$ kubectl get pods
NAME                                   READY     STATUS              RESTARTS   AGE
kubernetes-bootcamp-2100875782-0v3ql   0/1       ContainerCreating   0          2s
kubernetes-bootcamp-2100875782-415gm   1/1       Running             0          23m
kubernetes-bootcamp-2100875782-l7525   1/1       Running             0          23m
kubernetes-bootcamp-2100875782-q8c18   1/1       Running             0          23m
```

```
$ kubectl get pods
NAME                                   READY     STATUS    RESTARTS   AGE
kubernetes-bootcamp-2100875782-0v3ql   1/1       Running   0          10s
kubernetes-bootcamp-2100875782-415gm   1/1       Running   0          23m
kubernetes-bootcamp-2100875782-l7525   1/1       Running   0          23m
kubernetes-bootcamp-2100875782-q8c18   1/1       Running   0          23m
```

戻った

```
$ kubectl describe pods | grep Image:
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
    Image:		jocatalin/kubernetes-bootcamp:v2
```

さて、つぎは multi node な Kubernetes Cluster を作らねば。
