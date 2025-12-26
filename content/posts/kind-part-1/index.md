---
title: 'kind で kubernetes に触れる (1)'
date: 2019-12-20T08:39:43+00:00
draft: false
tags: ['Kubernetes']
author: "@yteraoka"
image: cover.png
categories:
  - IT
---

kind のインストール
------------

```
$ curl -Lo ~/bin/kind \
    https://github.com/kubernetes-sigs/kind/releases/download/v0.6.1/kind-$(uname)-amd64
$ chmod +x ~/bin/kind
$ kind version
```

クラスタの作成・削除
----------

### クラスタの作成

```
$ kind create cluster
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.16.3) 🖼 
 ✓ Preparing nodes 📦 
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Not sure what to do next? 😅 Check out [https://kind.sigs.k8s.io/docs/user/quick-start/](https://kind.sigs.k8s.io/docs/user/quick-start/)
```

kubectl コマンドのインストール

```
$ k8sversion=v1.16.3
$ curl -Lo ~/bin/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/$k8sversion/bin/$(uname | tr A-Z a-z)/amd64/kubectl
$ chmod +x ~/bin/kubectl
```

```
$ kubectl cluster-info --context kind-kind
Kubernetes master is running at https://127.0.0.1:39585
KubeDNS is running at https://127.0.0.1:39585/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### 別名のクラスタを追加で作成

```
$ kind create cluster --name kind2
(snip)
kubectl cluster-info --context kind-kind2
```

### クラスタの一覧を確認

```
$ kind get clusters
kind
kind2
```

複数のクラスタは kubectl コマンドで context を指定することで切り替えられる。後述の kubectx を使うと便利

### クラスタの削除

```
$ kind delete cluster
Deleting cluster "kind" ...
$ kind delete cluster --name kind2
Deleting cluster "kind2" ...
```

作成、削除で `~/.kube/config` が更新されるので context を指定するだけでクラスタにアクセスできる。

マルチノードクラスタ
----------

### 1 Control Plane + 2 Workers

```
$ cat 1cp-2wk-cluster.yml
# three node (two workers) cluster
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

```
$ kind create cluster --config 1cp-2wk-cluster.yml 
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.16.3) 🖼
 ✓ Preparing nodes 📦 
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a nice day! 👋
```

### 3 Control Planes + 3 Workers

```
$ cat 3cp-3wk-cluster.yml
# a cluster with 3 control-plane nodes and 3 workers
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
```

```
$ kind create cluster --config 3cp-3wk-cluster.yml 
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.16.3) 🖼
 ✓ Preparing nodes 📦 
 ✓ Configuring the external load balancer ⚖️ 
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
 ✓ Joining more control-plane nodes 🎮 
 ✓ Joining worker nodes 🚜 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a nice day! 👋
```

```
$ kubectl get pods --namespace kube-system
NAME                                          READY   STATUS    RESTARTS   AGE
coredns-5644d7b6d9-hznzl                      1/1     Running   0          9m55s
coredns-5644d7b6d9-p79sd                      1/1     Running   0          9m55s
etcd-kind-control-plane                       1/1     Running   0          7m20s
etcd-kind-control-plane2                      1/1     Running   0          9m8s
etcd-kind-control-plane3                      1/1     Running   0          8m11s
kindnet-9gppd                                 1/1     Running   0          9m9s
kindnet-ht8rw                                 1/1     Running   0          7m34s
kindnet-lc8l7                                 1/1     Running   0          7m34s
kindnet-q78sq                                 1/1     Running   0          7m35s
kindnet-xncxc                                 1/1     Running   0          9m35s
kindnet-zvkcs                                 1/1     Running   0          8m12s
kube-apiserver-kind-control-plane             1/1     Running   0          9m9s
kube-apiserver-kind-control-plane2            1/1     Running   0          8m
kube-apiserver-kind-control-plane3            1/1     Running   1          8m1s
kube-controller-manager-kind-control-plane    1/1     Running   1          9m10s
kube-controller-manager-kind-control-plane2   1/1     Running   0          8m1s
kube-controller-manager-kind-control-plane3   1/1     Running   0          7m22s
kube-proxy-5vbrr                              1/1     Running   0          7m35s
kube-proxy-6rqgc                              1/1     Running   0          7m34s
kube-proxy-dks2d                              1/1     Running   0          9m55s
kube-proxy-hd9dg                              1/1     Running   0          7m34s
kube-proxy-jkxvd                              1/1     Running   0          8m12s
kube-proxy-k546b                              1/1     Running   0          9m9s
kube-scheduler-kind-control-plane             1/1     Running   1          8m55s
kube-scheduler-kind-control-plane2            1/1     Running   0          7m55s
kube-scheduler-kind-control-plane3            1/1     Running   0          6m57s
```

クラスタのカスタマイズ
-----------

### Pod Subnet

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.244.0.0/16"
```

[Pod Subnet](https://kind.sigs.k8s.io/docs/user/configuration/#pod-subnet)

### Service Subnet

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  serviceSubnet: "10.96.0.0/12"
```

[Service Subnet](https://kind.sigs.k8s.io/docs/user/configuration/#service-subnet)

### デフォルト CNI を無効にする

デフォルトでは kindnetd という CNI がセットアップされるが、Calico など別の CNI を使いたい場合はこれを無効にしておく。

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  # the default CNI will not be installed
  disableDefaultCNI: true
```

Calico を使う
----------

### default CNI (kindnetd) を無効にした Cluster の作成

前項の手順で default CNI を無効にした cluster を作成する

```
$ kind create cluster --config disable-default-cni.yml 
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.16.3) 🖼
 ✓ Preparing nodes 📦 
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Not sure what to do next? 😅 Check out https://kind.sigs.k8s.io/docs/user/quick-start/
```

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                         READY   STATUS    RESTARTS   AGE
kube-system   coredns-5644d7b6d9-4fvl4                     0/1     Pending   0          62s
kube-system   coredns-5644d7b6d9-8rskp                     0/1     Pending   0          62s
kube-system   etcd-kind-control-plane                      1/1     Running   0          17s
kube-system   kube-apiserver-kind-control-plane            1/1     Running   0          24s
kube-system   kube-controller-manager-kind-control-plane   0/1     Pending   0          2s
kube-system   kube-proxy-pcnt4                             1/1     Running   0          62s
kube-system   kube-scheduler-kind-control-plane            0/1     Pending   0          8s
```

CNI を無効にしているため CoreDNS が Pending 状態となっている

Pod Subnet を確認

```
$ kubectl cluster-info dump | grep -- --cluster-cidr
                            "--cluster-cidr=10.244.0.0/16",
```

calico.yaml の CALICO\_IPV4POOL\_CIDR をクラスタの Pod Subnet に合わせる

```
$ curl -s https://docs.projectcalico.org/v3.11/manifests/calico.yaml | sed 's,192.168.0.0/16,10.244.0.0/16,' > calico.yaml
```

```
$ kubectl apply -f calico.yaml
configmap/calico-config created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
clusterrole.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrolebinding.rbac.authorization.k8s.io/calico-kube-controllers created
clusterrole.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
daemonset.apps/calico-node created
serviceaccount/calico-node created
deployment.apps/calico-kube-controllers created
serviceaccount/calico-kube-controllers created
```

しばらく待つと Calico の Pod と CoreDNS の Pod が Running になっていることが確認できる

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                         READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-648f4868b8-ghzdt     1/1     Running   0          79s
kube-system   calico-node-mnftc                            1/1     Running   0          79s
kube-system   coredns-5644d7b6d9-4fvl4                     1/1     Running   0          6m29s
kube-system   coredns-5644d7b6d9-8rskp                     1/1     Running   0          6m29s
kube-system   etcd-kind-control-plane                      1/1     Running   0          5m44s
kube-system   kube-apiserver-kind-control-plane            1/1     Running   0          5m51s
kube-system   kube-controller-manager-kind-control-plane   1/1     Running   0          5m29s
kube-system   kube-proxy-pcnt4                             1/1     Running   0          6m29s
kube-system   kube-scheduler-kind-control-plane            1/1     Running   0          5m35s
```

Krew
----

kubectl plugin の Package manager [krew.dev](https://krew.dev). kubectx や kubens をインストールするのに使う。

```bash
(
  set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v0.3.3/krew.{tar.gz,yaml}" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
  "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz &&
  "$KREW" update
)
```

```
Installing plugin: krew
Installed plugin: krew
\
 | Use this plugin:
 | 	kubectl krew
 | Documentation:
 | 	https://sigs.k8s.io/krew
 | Caveats:
 | \
 |  | krew is now installed! To start using kubectl plugins, you need to add
 |  | krew's installation directory to your PATH:
 |  | 
 |  |   * macOS/Linux:
 |  |     - Add the following to your ~/.bashrc or ~/.zshrc:
 |  |         export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
 |  |     - Restart your shell.
 |  | 
 |  |   * Windows: Add %USERPROFILE%\.krew\bin to your PATH environment variable
 |  | 
 |  | To list krew commands and to get help, run:
 |  |   $ kubectl krew
 |  | For a full list of available plugins, run:
 |  |   $ kubectl krew search
 |  | 
 |  | You can find documentation at https://sigs.k8s.io/krew.
 | /
/
WARNING: You installed a plugin from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
+ ./krew-linux_amd64 update
Updated the local copy of plugin index.
```

```bash
PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
```

```
$ kubectl krew
krew is the kubectl plugin manager.
You can invoke krew through kubectl: "kubectl krew [command]..."

Usage:
  krew [command]

Available Commands:
  help        Help about any command
  info        Show information about a kubectl plugin
  install     Install kubectl plugins
  list        List installed kubectl plugins
  search      Discover kubectl plugins
  uninstall   Uninstall plugins
  update      Update the local copy of the plugin index
  upgrade     Upgrade installed plugins to newer versions
  version     Show krew version and diagnostics

Flags:
  -h, --help      help for krew
  -v, --v Level   number for the log level verbosity

Use "krew [command] --help" for more information about a command.
```

kubectx, kubens
---------------

Cluster と Namespace の切り替えを楽ちんにするツール。[kubectx.dev](https://kubectx.dev).

### インストール

上記の krew を使ってインストールする

```
kubectl krew install ctx
Updated the local copy of plugin index.
Installing plugin: ctx
Installed plugin: ctx
\
 | Use this plugin:
 | 	kubectl ctx
 | Documentation:
 | 	https://github.com/ahmetb/kubectx
 | Caveats:
 | \
 |  | If fzf is installed on your machine, you can interactively choose
 |  | between the entries using the arrow keys, or by fuzzy searching
 |  | as you type.
 |  | 
 |  | See https://github.com/ahmetb/kubectx for customization and details.
 | /
/
WARNING: You installed a plugin from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
```

```
$ kubectl krew install ns
Updated the local copy of plugin index.
Installing plugin: ns
Installed plugin: ns
\
 | Use this plugin:
 | 	kubectl ns
 | Documentation:
 | 	https://github.com/ahmetb/kubectx
 | Caveats:
 | \
 |  | If fzf is installed on your machine, you can interactively choose
 |  | between the entries using the arrow keys, or by fuzzy searching
 |  | as you type.
 |  | 
 |  | See https://github.com/ahmetb/kubectx for customization and details.
 | /
/
WARNING: You installed a plugin from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
```

krew でインストールした場合は `kubectx` コマンドではなく `kubectl ctx` として実行する

kubectl tree
------------

Twitter で [kubectl tree](https://github.com/ahmetb/kubectl-tree) という便利ツールを知ったのでこれもインストール。

```
kubectl krew install tree
```

{{< x user="ahmetb" id="1212792452064501760" >}}

