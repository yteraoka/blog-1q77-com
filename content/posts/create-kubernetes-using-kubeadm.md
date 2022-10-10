---
title: 'kubeadm で kubernetes を構築'
date: Mon, 30 Apr 2018 13:52:13 +0000
draft: false
tags: ['DigitalOcean', 'Kubernetes', 'ansible']
---

DigitalOcean の Community サイトにある [Tutorials](https://www.digitalocean.com/community/tutorials) に「[How To Create a Kubernetes 1.10 Cluster Using Kubeadm on Ubuntu 16.04](https://www.digitalocean.com/community/tutorials/how-to-create-a-kubernetes-1-10-cluster-using-kubeadm-on-ubuntu-16-04)」というのがあったので試してみる。 Tutorial 書いて提供するとお金がもらえる（[Write for DOnations](https://www.digitalocean.com/write-for-donations/)）ということでなんかすごいペースで増えてる気がする

### Goal

master 1台、worker 2台という構成の Kubernetes を構築します

### Prerequisites

1GB以上のメモリを積んだ Ubuntu 16.04 のサーバー3台を用意します (2GB Memory, 1vCPU, 50GB SSD $10/mo ($0.015/hr) のサーバーを3台用意しました)

### Step 1 - Setting Up the Workspace Directory and Ansible Inventory File

[kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm/) を使えるようにするまでのセットアップを Ansible で行うため Inventory ファイルを作成

### Step 2 - Creating a Non-Root User on All Remote Servers

DigitalOcean はサーバー作成直後は root でログインする仕様なので non-root ユーザーを Ansible で作成します ubuntu という名前のユーザーで、SSH でログインでき、sudo で root になれるユーザーを作成します

### Step 3 - Installing Kubernetetes' Dependencies

* Docker のインストール
* Kubernetes の apt リポジトリ登録
* kubelet のインストール (apt)
* kubeadm のインストール (apt)
* kubectl のインストール (apt) (master のみ)

### Step 4 - Setting Up the Master Node

* `kubeadm init --pod-network-cidr=10.244.0.0/16` の実行
* `kubeadm init` で作成された `/etc/kubernetes/admin.conf` を `/home/ubuntu/.kube/config` にコピー
* `kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml` の実行

kubeadm init の実行時に crictl が無いよと言われるけど WARNING だからなくても大丈夫なのかな

```
        [WARNING FileExisting-crictl]: crictl not found in system path
Suggestion: go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
```

master 1台だけの kubernetes ができたっぽい

```
ubuntu@master1:~$ kubectl get nodes
NAME      STATUS    ROLES     AGE       VERSION
master1   Ready     master    24m       v1.10.2
```

次のような Pod が起動している

```
ubuntu@master1:~$ kubectl get pods --all-namespaces
NAMESPACE     NAME                              READY     STATUS    RESTARTS   AGE
kube-system   etcd-master1                      1/1       Running   0          23m
kube-system   kube-apiserver-master1            1/1       Running   0          23m
kube-system   kube-controller-manager-master1   1/1       Running   0          24m
kube-system   kube-dns-86f4d74b45-g4wvf         3/3       Running   0          24m
kube-system   kube-flannel-ds-rjnww             1/1       Running   0          45s
kube-system   kube-proxy-p9p7p                  1/1       Running   0          24m
kube-system   kube-scheduler-master1            1/1       Running   0          24m
```

### Step 5 - Setting Up the Worker Nodes

Master で `kubeadm token create --print-join-command` を実行して出力されるコマンドを Worker の2台で実行します

### Step 6 - Verifying the Cluster

```
ubuntu@master1:~$ kubectl get nodes
NAME      STATUS     ROLES     AGE       VERSION
master1   Ready      master    1h        v1.10.2
worker1   NotReady   10s       v1.10.2
worker2   NotReady   7s        v1.10.2
ubuntu@master1:~$ kubectl get nodes
NAME      STATUS    ROLES     AGE       VERSION
master1   Ready     master    1h        v1.10.2
worker1   Ready     40s       v1.10.2
worker2   Ready     37s       v1.10.2
ubuntu@master1:~$ 
```

2台の worker サーバーが kubernetes Cluster に追加されました

```
ubuntu@master1:~$ kubectl get pods --all-namespaces
NAMESPACE     NAME                              READY     STATUS    RESTARTS   AGE
kube-system   etcd-master1                      1/1       Running   0          1h
kube-system   kube-apiserver-master1            1/1       Running   0          1h
kube-system   kube-controller-manager-master1   1/1       Running   0          1h
kube-system   kube-dns-86f4d74b45-g4wvf         3/3       Running   0          1h
kube-system   kube-flannel-ds-2rqp5             1/1       Running   0          3m
kube-system   kube-flannel-ds-rjnww             1/1       Running   0          52m
kube-system   kube-flannel-ds-src6q             1/1       Running   1          3m
kube-system   kube-proxy-g5ptc                  1/1       Running   0          3m
kube-system   kube-proxy-p9p7p                  1/1       Running   0          1h
kube-system   kube-proxy-vwvgk                  1/1       Running   0          3m
kube-system   kube-scheduler-master1            1/1       Running   0          1h
ubuntu@master1:~$
```

kube-flannel と kube-proxy が worker node 分増えました

### Step 7 - Running An Application on the Cluster

`kubectl run` で nginx コンテナを実行してみます

```
ubuntu@master1:~$ kubectl run nginx --image=nginx --port 80
deployment.apps "nginx" created
ubuntu@master1:~$ kubectl get pods
NAME                     READY     STATUS              RESTARTS   AGE
nginx-768979984b-sb72q   0/1       ContainerCreating   0          14s
ubuntu@master1:~$ kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
nginx-768979984b-sb72q   1/1       Running   0          50s
ubuntu@master1:~$
```

Pod の確認

```
ubuntu@master1:~$ kubectl describe pods
Name:           nginx-768979984b-sb72q
Namespace:      default
Node:           worker2/206.189.xxx.yyy
Start Time:     Mon, 30 Apr 2018 12:59:47 +0000
Labels:         pod-template-hash=3245355406
                run=nginx
Annotations:    Status:         Running
IP:             10.244.2.2
Controlled By:  ReplicaSet/nginx-768979984b
Containers:
  nginx:
    Container ID:   docker://8edc1fb94d6e3a43fba0074b4af14d6f1ee3617e4568036dccfe30990a22c305
    Image:          nginx
    Image ID:       docker-pullable://nginx@sha256:80e2f223b2a53cfcf3fd491521e5fb9b4004d42dfc391c76011bcdd9565643df
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Mon, 30 Apr 2018 13:00:01 +0000
    Ready:          True
    Restart Count:  0
    Environment:    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-ttfqw (ro)
Conditions:
  Type           Status
  Initialized    True
  Ready          True
  PodScheduled   True
Volumes:
  default-token-ttfqw:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-ttfqw
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason                 Age   From               Message
  ----    ------                 ----  ----               -------
  Normal  Scheduled              2m    default-scheduler  Successfully assigned nginx-768979984b-sb72q to worker2
  Normal  SuccessfulMountVolume  2m    kubelet, worker2   MountVolume.SetUp succeeded for volume "default-token-ttfqw"
  Normal  Pulling                2m    kubelet, worker2   pulling image "nginx"
  Normal  Pulled                 2m    kubelet, worker2   Successfully pulled image "nginx"
  Normal  Created                2m    kubelet, worker2   Created container
  Normal  Started                2m    kubelet, worker2   Started container
ubuntu@master1:~$ 
```

Deployment の確認

```
ubuntu@master1:~$ kubectl get deployments
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx     1         1         1            1           5m
ubuntu@master1:~$
```

```
ubuntu@master1:~$ kubectl describe deployments
Name:                   nginx
Namespace:              default
CreationTimestamp:      Mon, 30 Apr 2018 12:59:47 +0000
Labels:                 run=nginx
Annotations:            deployment.kubernetes.io/revision=1
Selector:               run=nginx
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  1 max unavailable, 1 max surge
Pod Template:
  Labels:  run=nginx
  Containers:
   nginx:
    Image:        nginx
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  Mounts:       Volumes:        Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  NewReplicaSet:   nginx-768979984b (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  6m    deployment-controller  Scaled up replica set nginx-768979984b to 1
ubuntu@master1:~$ 
```

このままでは外からアクセスできないため service を作成します 作成前

```
ubuntu@master1:~$ kubectl get services
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    443/TCP   2h
ubuntu@master1:~$ 
```

`kubectl expose` で `NodePort` を指定

```
ubuntu@master1:~$ kubectl expose deploy nginx --port 80 --target-port 80 --type NodePort
service "nginx" exposed
ubuntu@master1:~$
```

nginx サービスが作られました

```
ubuntu@master1:~$ kubectl get services
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       443/TCP        2h
nginx        NodePort    10.108.40.119   80:30622/TCP   2s
ubuntu@master1:~$ 
```

master1, worker1, worker2 3台にて kube-proxy が 30622 を listen しており、どの node の 30622 ポートにアクセスしても nginx へ proxy されるようになっています

```
ubuntu@master1:~$ sudo ss -nltp | grep 30622
LISTEN     0      128         :::30622                   :::*                   users:(("kube-proxy",pid=7067,fd=8))
ubuntu@master1:~$
```

```
ubuntu@worker1:~$ sudo ss -nltp | grep 30622
LISTEN     0      128         :::30622                   :::*                   users:(("kube-proxy",pid=10000,fd=8))
ubuntu@worker1:~$
```

```
ubuntu@worker2:~$ sudo ss -nltp | grep 30622
LISTEN     0      128         :::30622                   :::*                   users:(("kube-proxy",pid=9769,fd=8))
ubuntu@worker2:~$
```

Service の削除

```
ubuntu@master1:~$ kubectl delete service nginx
service "nginx" deleted
ubuntu@master1:~$
```

消えました。kube-proxy プロセスはいますが 30622 ポートはもう開かれていません。

```
ubuntu@master1:~$ kubectl get services
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    443/TCP   3h
ubuntu@master1:~$ 
```

Deployment の削除

```
ubuntu@master1:~$ kubectl get deployments
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx     1         1         1            1           35m
ubuntu@master1:~$
```

消えました

```
ubuntu@master1:~$ kubectl delete deployment nginx
deployment.extensions "nginx" deleted
ubuntu@master1:~$ kubectl get deployments
No resources found.
ubuntu@master1:~$
```

Kubernetes も Docker Swarm 並に簡単にセットアップできるようになってきてますね。

[Using kubeadm to Create a Cluster](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/) からもっといろいろ調べてみよう。
