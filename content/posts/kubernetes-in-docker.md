---
title: 'Kubernetes in docker の使い方'
date: Mon, 26 Aug 2019 15:18:16 +0000
draft: false
tags: ['Docker', 'Kubernetes']
---

[Kubernetes in docker (kind)](https://github.com/kubernetes-sigs/kind) を使えるようになっておこうと思います。今回は DigitalOcean の CentOS 7 で試す。

Docker CE のインストール
-----------------

[Get Docker Engine - Community for CentOS](https://docs.docker.com/install/linux/docker-ce/centos/)

```
sudo yum remove docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-engine
```

```
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
```

```
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
```

```
sudo yum install docker-ce docker-ce-cli containerd.io
```

```
sudo usermod -a -G docker centos
```

```
sudo systemctl start docker
sudo systemctl enable docker
```

kind のインストール
------------

```
sudo curl -Lo /usr/bin/kind https://github.com/kubernetes-sigs/kind/releases/download/v0.5.1/kind-linux-amd64
sudo chmod +x /usr/bin/kind
```

kubectl のインストール
---------------

```
sudo curl -Lo /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
sudo chmod +x /usr/bin/kubectl
```

kind の実行
--------

`kind create cluster` と実行するだけで Kubernetes クラスタが起動する。

```
$ kind create cluster
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.15.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Creating kubeadm config 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Cluster creation complete. You can now use the cluster with:

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
kubectl cluster-info
```

けど、docker ps では1コンテナ起動してるだけだな

```
$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS                                  NAMES
260a0db4daf7        kindest/node:v1.15.3   "/usr/local/bin/entr…"   13 minutes ago      Up 13 minutes       37630/tcp, 127.0.0.1:37630->6443/tcp   kind-control-plane
```

docker exec で ps してみると次のようになっている

```
# ps auxwwf
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root      9013  0.2  0.0   4040  2076 pts/1    Ss   14:25   0:00 bash
root      9122  0.0  0.0   5972  1464 pts/1    R+   14:25   0:00  \_ ps auxwwf
root         1  0.0  0.0  17648  6260 ?        Ss   14:10   0:00 /sbin/init
root        34  0.0  0.0  24640  6648 ?        S<s  14:10   0:00 /lib/systemd/systemd-journald
root        45  2.1  0.6 2360932 48788 ?       Ssl  14:10   0:19 /usr/bin/containerd
root       283  0.0  0.0  10732  3768 ?        Sl   14:10   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/03e619f69de43ddc43b1641fb24ac9b0b0c362aa6018999b81b6e894995b72bb -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       349  0.0  0.0   1012     4 ?        Ss   14:10   0:00  |   \_ /pause
root       294  0.0  0.0   9324  3308 ?        Sl   14:10   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/6fd68362e810b18a2356142f473499626842e55fd1e38dc60dd602c2b4f918c6 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       329  0.0  0.0   1012     4 ?        Ss   14:10   0:00  |   \_ /pause
root       316  0.0  0.0  10732  3796 ?        Sl   14:10   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/9f055513abd1d8723515ad210dfcd3b31ce8d262d3aacbe48bbe575c4e46ac31 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       358  0.0  0.0   1012     4 ?        Ss   14:10   0:00  |   \_ /pause
root       317  0.0  0.0  10732  3564 ?        Sl   14:10   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/14df61c598ebf1f6fed8bebc9c4f80b1f11a37a16c29f175d66136525c9e6b60 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       363  0.0  0.0   1012     4 ?        Ss   14:10   0:00  |   \_ /pause
root       491  0.0  0.0  10732  3540 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/d71810b32bd0ae25b4406449803f7ef496f5ca3cbd6f784557538b654871b709 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       508  0.3  0.3 141480 29196 ?        Ssl  14:11   0:02  |   \_ kube-scheduler --bind-address=127.0.0.1 --kubeconfig=/etc/kubernetes/scheduler.conf --leader-elect=true
root       542  0.0  0.0  10732  3716 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/b9dcfe2ef38c93bbc0cb9dbde378b4a5824ccc208c86d39629d668dc4cd58489 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       574  1.8  0.9 217568 72104 ?        Ssl  14:11   0:16  |   \_ kube-controller-manager --allocate-node-cidrs=true --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf --bind-address=127.0.0.1 --client-ca-file=/etc/kubernetes/pki/ca.crt --cluster-cidr=10.244.0.0/16 --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt --cluster-signing-key-file=/etc/kubernetes/pki/ca.key --controllers=*,bootstrapsigner,tokencleaner --enable-hostpath-provisioner=true --kubeconfig=/etc/kubernetes/controller-manager.conf --leader-elect=true --node-cidr-mask-size=24 --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --root-ca-file=/etc/kubernetes/pki/ca.crt --service-account-private-key-file=/etc/kubernetes/pki/sa.key --use-service-account-credentials=true
root       551  0.2  0.0  11788  4804 ?        Sl   14:11   0:02  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/973aec49f3de28367798e25733cd4863397cccc9aab775d9dbcbe145381f787c -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       580  1.9  0.4 10537600 34244 ?      Ssl  14:11   0:17  |   \_ etcd --advertise-client-urls=https://172.17.0.2:2379 --cert-file=/etc/kubernetes/pki/etcd/server.crt --client-cert-auth=true --data-dir=/var/lib/etcd --initial-advertise-peer-urls=https://172.17.0.2:2380 --initial-cluster=kind-control-plane=https://172.17.0.2:2380 --key-file=/etc/kubernetes/pki/etcd/server.key --listen-client-urls=https://127.0.0.1:2379,https://172.17.0.2:2379 --listen-peer-urls=https://172.17.0.2:2380 --name=kind-control-plane --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt --peer-client-cert-auth=true --peer-key-file=/etc/kubernetes/pki/etcd/peer.key --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt --snapshot-count=10000 --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
root       639  0.0  0.0  10732  3628 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/af9f6dfbc2bb2a8b807e0028de9020c77dea646339b835cc90be74884e6264bd -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       661  3.8  2.8 402920 224844 ?       Ssl  14:11   0:34  |   \_ kube-apiserver --advertise-address=172.17.0.2 --allow-privileged=true --authorization-mode=Node,RBAC --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-admission-plugins=NodeRestriction --enable-bootstrap-token-auth=true --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key --etcd-servers=https://127.0.0.1:2379 --insecure-port=0 --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key --requestheader-allowed-names=front-proxy-client --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --requestheader-extra-headers-prefix=X-Remote-Extra- --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --secure-port=6443 --service-account-key-file=/etc/kubernetes/pki/sa.pub --service-cluster-ip-range=10.96.0.0/12 --tls-cert-file=/etc/kubernetes/pki/apiserver.crt --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
root       862  0.0  0.0   9324  3536 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/4879d4a5e3d75990f15f95fb7e54c1afb80396fe59fcfcab4f43efc47e9103ff -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       879  0.0  0.0   1012     4 ?        Ss   14:11   0:00  |   \_ /pause
root       884  0.0  0.0   9324  3400 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/e9f36ddb48b6571ba9998ac5a5625b92c2b9908b9b7070d8566af02860295d74 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       907  0.0  0.0   1012     4 ?        Ss   14:11   0:00  |   \_ /pause
root       963  0.0  0.0   9324  3240 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/f6fd15e55e522bc4b48ba3b1672963e2ad652f3d04c69a60fae9bfa0a026924a -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root      1002  0.1  0.3 139724 24172 ?        Ssl  14:11   0:01  |   \_ /usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/config.conf --hostname-override=kind-control-plane
root       967  0.0  0.0  10732  5264 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/bf7aea0752d89b06394670a2ce49da52096604beff7cfeddaf057eb83d6c030d -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root       995  0.0  0.1 130224 15516 ?        Ssl  14:11   0:00  |   \_ /bin/kindnetd
root      1246  0.0  0.0  10796  3500 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/828fb3f0c098eb67209152d7697c468bfe9fa508a440f3bb9b56120ae6336f3e -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root      1263  0.0  0.0   1012     4 ?        Ss   14:11   0:00  |   \_ /pause
root      1297  0.0  0.0   9324  3544 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/3c1bbc921022e0151d4d32ca680462ea14130fd5e823cdfbf8317c275f90b4d3 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root      1314  0.3  0.3 142788 24596 ?        Ssl  14:11   0:02  |   \_ /coredns -conf /etc/coredns/Corefile
root      1375  0.0  0.0   9324  3628 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/11963940dfda62ca5eea86ebaeffc1441113b059423b9a1e4515165fe5d58b92 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root      1392  0.0  0.0   1012     4 ?        Ss   14:11   0:00  |   \_ /pause
root      1430  0.0  0.0  10732  3612 ?        Sl   14:11   0:00  \_ containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/bd01f1f3ae96c3b6a392c0055ac4a10afdadff7695078c7b34ce8a6de2decca7 -address /run/containerd/containerd.sock -containerd-binary /usr/bin/containerd
root      1447  0.2  0.3 142788 24136 ?        Ssl  14:11   0:02      \_ /coredns -conf /etc/coredns/Corefile
root       239  2.4  0.8 1623832 68848 ?       Ssl  14:10   0:22 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime=remote --container-runtime-endpoint=/run/containerd/containerd.sock --fail-swap-on=false --node-ip=172.17.0.2 --fail-swap-on=false
```

ふむふむ、Docker in Docker ですね。

### kubectl で確認

```
$ export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
$ kubectl cluster-info
Kubernetes master is running at https://127.0.0.1:37630
KubeDNS is running at https://127.0.0.1:37630/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
$ kubectl get services
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    443/TCP   33m
[centos@kind ~]$ kubectl get services --all-namespaces
NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
default       kubernetes   ClusterIP   10.96.0.1    443/TCP                  33m
kube-system   kube-dns     ClusterIP   10.96.0.10   53/UDP,53/TCP,9153/TCP   33m 
```

あ、たまたま kubectl と同じバージョンだったけどバージョン合わせるように気を付ける必要があるか

```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.3", GitCommit:"2d3c76f9091b6bec110a5e63777c332469e0cba2", GitTreeState:"clean", BuildDate:"2019-08-19T11:13:54Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.3", GitCommit:"2d3c76f9091b6bec110a5e63777c332469e0cba2", GitTreeState:"clean", BuildDate:"2019-08-20T18:57:36Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
```

Multi-node cluster
------------------

kind create に --config でコンフィグを渡せば node 数を指定することができる。[kind-example-config.yaml](https://raw.githubusercontent.com/kubernetes-sigs/kind/master/site/content/docs/user/kind-example-config.yaml)

```
curl -LO https://raw.githubusercontent.com/kubernetes-sigs/kind/master/site/content/docs/user/kind-example-config.yaml
```

```
$ kind create cluster --config kind-example-config.yaml
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.15.3) 🖼
 ✓ Preparing nodes 📦📦📦📦
 ✓ Creating kubeadm config 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Cluster creation complete. You can now use the cluster with:

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
kubectl cluster-info
```

```
$ kubectl get nodes
NAME                 STATUS   ROLES    AGE     VERSION
kind-control-plane   Ready    master   2m40s   v1.15.3
kind-worker          Ready    <none>   2m4s    v1.15.3
kind-worker2         Ready    <none>   2m4s    v1.15.3
kind-worker3         Ready    <none>   2m3s    v1.15.3
```

Control Plane も複数台にするには `kind-example-config.yaml` の nodes を次のように変更して `kind create` すれば Control Plane が3台になる

```
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
```

```
$ kubectl get nodes
NAME                  STATUS   ROLES    AGE     VERSION
kind-control-plane    Ready    master   2m36s   v1.15.3
kind-control-plane2   Ready    master   2m2s    v1.15.3
kind-control-plane3   Ready    master   86s     v1.15.3
kind-worker           Ready    60s     v1.15.3
kind-worker2          Ready    60s     v1.15.3
kind-worker3          Ready    60s     v1.15.3 
```

便利ツールだ。kind のドキュメントは [https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/) にある。
