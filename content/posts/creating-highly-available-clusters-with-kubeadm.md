---
title: 'kubeadm で外部 etcd で HA な Kubernetes クラスタをセットアップする'
date: Thu, 16 Aug 2018 14:59:22 +0000
draft: false
tags: ['Kubernetes', 'Kubernetes', 'calico', 'kubeadm']
---

etcd を外部にもつ HA な Kubernetes クラスタを kubeadm で構築します。[Creating Highly Available Clusters with kubeadm](https://kubernetes.io/docs/setup/independent/high-availability/#external-etcd) をなぞります。

### 各種バージョン情報

*   CentOS Linux release 7.5.1804
*   kubeadm v1.11.2 (GitCommit:"bb9ffb1654d4a729bb4cec18ff088eacc153c239")
*   docker 1.13.1 (docker-1.13.1-68.gitdded712.el7.centos.x86\_64)
*   kubelet v1.11.2 (Kubernetes v1.11.2)
*   etcd 3.2.18

### Set up the cluster

etcd クラスタは「[kubeadm で HA な etcd をセットアップ](/2018/08/setup-ha-etcd-with-kubeadm/)」の手順でセットアップ済みとします。

### Copy required files to other control plane nodes

etcd クラスタ作成で生成した次のファイルを kubernetes のコントロールプレーンとなるホストにコピーします。コントロール用プレーンに [kubeadm, docker, kubelet のインストール](/2018/08/install-kubeadm-on-centos7/)が必要です。

*   `/etc/kubernetes/pki/etcd/ca.crt`
*   `/etc/kubernetes/pki/apiserver-etcd-client.crt`
*   `/etc/kubernetes/pki/apiserver-etcd-client.key`

```
for s in HOST0 HOST1 HOST2; do
    scp /etc/kubernetes/pki/etcd/ca.crt \\
        /etc/kubernetes/pki/apiserver-etcd-client.crt \\
        /etc/kubernetes/pki/apiserver-etcd-client.key $s:
    ssh $s "sudo mkdir -p /etc/kubernetes/pki/etcd; sudo cp -p ca.crt /etc/kubernetes/pki/etcd/; sudo cp apiserver-etcd-client.crt apiserver-etcd-client.key /etc/kubernetes/pki/"
done

```

### Set up the first control plane node

1.  `kubeadm-config.yaml` テンプレートファイルを作成する
    
    ```
    apiVersion: kubeadm.k8s.io/v1alpha2
    kind: MasterConfiguration
    kubernetesVersion: v1.11.0
    apiServerCertSANs:
    - "LOAD\_BALANCER\_DNS"
    api:
        controlPlaneEndpoint: "LOAD\_BALANCER\_DNS:LOAD\_BALANCER\_PORT"
    etcd:
        external:
            endpoints:
            - https://ETCD\_0\_IP:2379
            - https://ETCD\_1\_IP:2379
            - https://ETCD\_2\_IP:2379
            caFile: /etc/kubernetes/pki/etcd/ca.crt
            certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
            keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
    networking:
        # This CIDR is a calico default. Substitute or remove for your CNI provider.
        podSubnet: "192.168.0.0/16"
    
    ```
    
2.  テンプレートの次の変数を適切な値に置換します
    
    *   `LOAD_BALANCER_DNS`
    *   `LOAD_BALANCER_PORT`
    *   `ETCD_0_IP`
    *   `ETCD_1_IP`
    *   `ETCD_2_IP`
3.  `kubeadm init --config kubeadm-config.yaml` を実行します
    
    APIサーバー container は 6443/tcp ポートを listen するのでロードバランサーからの転送先はこのポートを指定する必要があります
    

```
\[root@ctrl1 ~\]# kubeadm init --config kubeadm-config.yaml
\[endpoint\] WARNING: port specified in api.controlPlaneEndpoint overrides api.bindPort in the controlplane address
\[init\] using Kubernetes version: v1.11.0
\[preflight\] running pre-flight checks
I0816 12:26:37.018590   14467 kernel\_validator.go:81\] Validating kernel version
I0816 12:26:37.018733   14467 kernel\_validator.go:96\] Validating kernel config
        \[WARNING Service-Kubelet\]: kubelet service is not enabled, please run 'systemctl enable kubelet.service'
\[preflight/images\] Pulling images required for setting up a Kubernetes cluster
\[preflight/images\] This might take a minute or two, depending on the speed of your internet connection
\[preflight/images\] You can also perform this action in beforehand using 'kubeadm config images pull'
\[kubelet\] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
\[kubelet\] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
\[preflight\] Activating the kubelet service
\[certificates\] Generated ca certificate and key.
\[certificates\] Generated apiserver certificate and key.
\[certificates\] apiserver serving cert is signed for DNS names \[ctrl1 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local k8s-api.example k8s-api.example.com\] and IPs \[10.96.0.1 203.0.113.123\]
\[certificates\] Generated apiserver-kubelet-client certificate and key.
\[certificates\] Generated sa key and public key.
\[certificates\] Generated front-proxy-ca certificate and key.
\[certificates\] Generated front-proxy-client certificate and key.
\[certificates\] valid certificates and keys now exist in "/etc/kubernetes/pki"
\[endpoint\] WARNING: port specified in api.controlPlaneEndpoint overrides api.bindPort in the controlplane address
\[kubeconfig\] Wrote KubeConfig file to disk: "/etc/kubernetes/admin.conf"
\[kubeconfig\] Wrote KubeConfig file to disk: "/etc/kubernetes/kubelet.conf"
\[kubeconfig\] Wrote KubeConfig file to disk: "/etc/kubernetes/controller-manager.conf"
\[kubeconfig\] Wrote KubeConfig file to disk: "/etc/kubernetes/scheduler.conf"
\[controlplane\] wrote Static Pod manifest for component kube-apiserver to "/etc/kubernetes/manifests/kube-apiserver.yaml"
\[controlplane\] wrote Static Pod manifest for component kube-controller-manager to "/etc/kubernetes/manifests/kube-controller-manager.yaml"
\[controlplane\] wrote Static Pod manifest for component kube-scheduler to "/etc/kubernetes/manifests/kube-scheduler.yaml"
\[init\] waiting for the kubelet to boot up the control plane as Static Pods from directory "/etc/kubernetes/manifests"
\[init\] this might take a minute or longer if the control plane images have to be pulled
\[apiclient\] All control plane components are healthy after 71.020852 seconds
\[uploadconfig\] storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
\[kubelet\] Creating a ConfigMap "kubelet-config-1.11" in namespace kube-system with the configuration for the kubelets in the cluster
\[markmaster\] Marking the node ctrl1 as master by adding the label "node-role.kubernetes.io/master=''"
\[markmaster\] Marking the node ctrl1 as master by adding the taints \[node-role.kubernetes.io/master:NoSchedule\]
\[patchnode\] Uploading the CRI Socket information "/var/run/dockershim.sock" to the Node API object "ctrl1" as an annotation
\[bootstraptoken\] using token: e69t47.k98pkcidzvgexwbz
\[bootstraptoken\] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
\[bootstraptoken\] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
\[bootstraptoken\] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
\[bootstraptoken\] creating the "cluster-info" ConfigMap in the "kube-public" namespace
\[addons\] Applied essential addon: CoreDNS
\[endpoint\] WARNING: port specified in api.controlPlaneEndpoint overrides api.bindPort in the controlplane address
\[addons\] Applied essential addon: kube-proxy

Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f \[podnetwork\].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join k8s-api.example.com:443 --token e69t47.k98pkcidzvgexwbz --discovery-token-ca-cert-hash sha256:b0e28afb25529ad1405d6adecd4a154ace51b6245ff59477f5ea465e221936de

\[root@ctrl1 ~\]#

```1台目のコントロールプレーンサーバーが出来ました。ここで表示される `kubeadm join ...` コマンドは worker node を追加する際に使用しますが、忘れてしまっても `kubeadm token create` で作成可能です。忘れなくても 24 時間で有効期限が切れます。`kubeadm token list`, `kubeadm token delete` で確認や削除も可能です。 cert hash の方は次のようにして取得できます。```
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.\* //'
```

```
\# docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS               NAMES
9275bcc15515        1d3d7afd77d1           "/usr/local/bin/ku..."   54 minutes ago      Up 54 minutes                           k8s\_kube-proxy\_kube-proxy-csbw4\_kube-system\_e2d559d3-a14f-11e8-afea-5e45cb53c031\_0
a87d07e0927d        k8s.gcr.io/pause:3.1   "/pause"                 54 minutes ago      Up 54 minutes                           k8s\_POD\_kube-proxy-csbw4\_kube-system\_e2d559d3-a14f-11e8-afea-5e45cb53c031\_0
aa6575c2ebe6        214c48e87f58           "kube-apiserver --..."   55 minutes ago      Up 55 minutes                           k8s\_kube-apiserver\_kube-apiserver-ctrl1\_kube-system\_7a1112ade7b8b6480eabec800c07c9ce\_0
7a92eac6f28d        55b70b420785           "kube-controller-m..."   55 minutes ago      Up 55 minutes                           k8s\_kube-controller-manager\_kube-controller-manager-ctrl1\_kube-system\_7954798510b3874bbd133bb6fceac113\_0
997e4d0d65ff        0e4a34a3b0e6           "kube-scheduler --..."   55 minutes ago      Up 55 minutes                           k8s\_kube-scheduler\_kube-scheduler-ctrl1\_kube-system\_31eabaff7d89a40d8f7e05dfc971cdbd\_0
4eaff0f0743e        k8s.gcr.io/pause:3.1   "/pause"                 56 minutes ago      Up 55 minutes                           k8s\_POD\_kube-apiserver-ctrl1\_kube-system\_7a1112ade7b8b6480eabec800c07c9ce\_0
f344f457f0d2        k8s.gcr.io/pause:3.1   "/pause"                 56 minutes ago      Up 55 minutes                           k8s\_POD\_kube-controller-manager-ctrl1\_kube-system\_7954798510b3874bbd133bb6fceac113\_0
18a8824b734c        k8s.gcr.io/pause:3.1   "/pause"                 56 minutes ago      Up 55 minutes                           k8s\_POD\_kube-scheduler-ctrl1\_kube-system\_31eabaff7d89a40d8f7e05dfc971cdbd\_0

```

`/etc/kubernetes/admin.conf` を `$HOME/.kube/config` にコピーすると `kubectl` コマンドでアクセスできるようになります。([insall-kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl))

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                            READY     STATUS    RESTARTS   AGE
kube-system   coredns-78fcdf6894-c444w        0/1       Pending   0          55m
kube-system   coredns-78fcdf6894-v95pf        0/1       Pending   0          55m
kube-system   kube-apiserver-ctrl1            1/1       Running   0          54m
kube-system   kube-controller-manager-ctrl1   1/1       Running   0          55m
kube-system   kube-proxy-csbw4                1/1       Running   0          55m
kube-system   kube-scheduler-ctrl1            1/1       Running   0          58m

```おや？coredns が Pending なのはなぜだ？？

`/etc/kubernetes/` 配下のファイルは次のようになっています

```
\# find /etc/kubernetes/ -type f
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/apiserver-etcd-client.crt
/etc/kubernetes/pki/apiserver-etcd-client.key
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/apiserver.key
/etc/kubernetes/pki/apiserver.crt
/etc/kubernetes/pki/apiserver-kubelet-client.key
/etc/kubernetes/pki/apiserver-kubelet-client.crt
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.key
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-client.key
/etc/kubernetes/pki/front-proxy-client.crt
/etc/kubernetes/manifests/kube-apiserver.yaml
/etc/kubernetes/manifests/kube-controller-manager.yaml
/etc/kubernetes/manifests/kube-scheduler.yaml
/etc/kubernetes/admin.conf
/etc/kubernetes/kubelet.conf
/etc/kubernetes/controller-manager.conf
/etc/kubernetes/scheduler.conf

```

### Copy required files to the correct locations

`kubeadm init` で作成された次のファイルを他のコントロールプレーン用ホストにコピーします

*   `/etc/kubernetes/pki/ca.crt`
*   `/etc/kubernetes/pki/ca.key`
*   `/etc/kubernetes/pki/sa.key`
*   `/etc/kubernetes/pki/sa.pub`
*   `/etc/kubernetes/pki/front-proxy-ca.crt`
*   `/etc/kubernetes/pki/front-proxy-ca.key`

```
for host in HOST1 HOST2; do
  scp /etc/kubernetes/pki/ca.crt \\
      /etc/kubernetes/pki/ca.key \\
      /etc/kubernetes/pki/sa.key \\
      /etc/kubernetes/pki/sa.pub \\
      /etc/kubernetes/pki/front-proxy-ca.crt \\
      /etc/kubernetes/pki/front-proxy-ca.key $host:
done

```

### Set up the other control plane nodes

1.  コピーしたファイルが次の場所にあることを確認
    *   `/etc/kubernetes/pki/apiserver-etcd-client.crt`
    *   `/etc/kubernetes/pki/apiserver-etcd-client.key`
    *   `/etc/kubernetes/pki/ca.crt`
    *   `/etc/kubernetes/pki/ca.key`
    *   `/etc/kubernetes/pki/front-proxy-ca.crt`
    *   `/etc/kubernetes/pki/front-proxy-ca.key`
    *   `/etc/kubernetes/pki/sa.key`
    *   `/etc/kubernetes/pki/sa.pub`
    *   `/etc/kubernetes/pki/etcd/ca.crt`
2.  `kubeadm init --config kubeadm-config.yaml`をそれぞれのホストで実行する（`kubeadm join` ではない）
    

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                            READY     STATUS    RESTARTS   AGE
kube-system   coredns-78fcdf6894-c444w        0/1       Pending   0          1h
kube-system   coredns-78fcdf6894-v95pf        0/1       Pending   0          1h
kube-system   kube-apiserver-ctrl1            1/1       Running   0          1h
kube-system   kube-apiserver-ctrl2            1/1       Running   0          11m
kube-system   kube-apiserver-ctrl3            1/1       Running   0          4s
kube-system   kube-controller-manager-ctrl1   1/1       Running   0          1h
kube-system   kube-controller-manager-ctrl2   1/1       Running   0          11m
kube-system   kube-controller-manager-ctrl3   1/1       Running   0          4s
kube-system   kube-proxy-csbw4                1/1       Running   0          1h
kube-system   kube-proxy-vtq7h                1/1       Running   0          24s
kube-system   kube-proxy-xdl86                1/1       Running   0          11m
kube-system   kube-scheduler-ctrl1            1/1       Running   0          1h
kube-system   kube-scheduler-ctrl2            1/1       Running   0          11m
kube-system   kube-scheduler-ctrl3            1/1       Running   0          4s

```coredns が Pending なのは [pod network add-on](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#pod-network) のインストールがまだだからのもよう

```
$ kubectl get nodes
NAME      STATUS     ROLES     AGE       VERSION
ctrl1     NotReady   master    1h        v1.11.2
ctrl2     NotReady   master    11m       v1.11.2
ctrl3     NotReady   master    10s       v1.11.2

```STATUS が NotReady なのも network の問題かな

### Installing a pod network add-on

[Calico](https://www.projectcalico.org/) をインストール

```
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

```

```
$ kubectl get pods -n kube-system
NAME                            READY     STATUS    RESTARTS   AGE
calico-node-nq9mr               2/2       Running   0          31s
calico-node-pt4kk               2/2       Running   0          31s
calico-node-qf29t               2/2       Running   0          31s
coredns-7d4db77c45-5vzf2        1/1       Running   0          34m
coredns-7d4db77c45-jkgdj        1/1       Running   0          34m
kube-apiserver-ctrl1            1/1       Running   1          2h
kube-apiserver-ctrl2            1/1       Running   1          1h
kube-apiserver-ctrl3            1/1       Running   1          54m
kube-controller-manager-ctrl1   1/1       Running   1          2h
kube-controller-manager-ctrl2   1/1       Running   1          1h
kube-controller-manager-ctrl3   1/1       Running   2          54m
kube-proxy-csbw4                1/1       Running   1          2h
kube-proxy-vtq7h                1/1       Running   1          55m
kube-proxy-xdl86                1/1       Running   1          1h
kube-scheduler-ctrl1            1/1       Running   1          2h
kube-scheduler-ctrl2            1/1       Running   1          1h
kube-scheduler-ctrl3            1/1       Running   1          54m

```キタ！

```
$ kubectl get nodes
NAME      STATUS    ROLES     AGE       VERSION
ctrl1     Ready     master    2h        v1.11.2
ctrl2     Ready     master    1h        v1.11.2
ctrl3     Ready     master    55m       v1.11.2

```node の STATUS も Ready になった！

Calico をインストールする前に CoreDNS が起動しないな？と調べてて `allowPrivilegeEscalation: false` を `true` にするか SELinux を無効にする必要があるっていう issue を見つけて、先にやってしまったのだが、必要だったかどうかを今度確認する。不要でした。 [CoreDNS not started with k8s 1.11 and weave (CentOS 7)](https://github.com/kubernetes/kubeadm/issues/998)

### Worker node の追加

[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/) で追加します。