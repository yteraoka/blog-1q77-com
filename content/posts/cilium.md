---
title: 'Cilium ってなんだ？'
date: Wed, 09 May 2018 15:03:10 +0000
draft: false
tags: ['Cilium', 'Cilium', 'Kubernetes', 'minikube']
---

[Cilium 1.0: Bringing the BPF Revolution to Kubernetes Networking and Security](https://cilium.io/blog/2018/04/24/cilium-10/) という記事を見かけた Cilium っていうのが Version 1.0 になったそうだ。はて？これは何をもったらすものだろう？ コンテナ化、マイクロサービス化が進みさまざまなサービス同士が通信するようになりますが、守るべき API があるし、どことどこの通信を許可するかというのを iptables による L3, L4 での制御ではスケールしない、ルールが万を超えたり、非常に頻繁に更新する必要もあるため BPF というものでもっとシンプルにしようというもののようです [Introduction to Cilium](http://docs.cilium.io/en/doc-1.0/intro/) では機能として次のようなものが挙げられています

*   Protect and secure APIs transparently
*   Secure service to service communication based on identities
*   Secure access to and from external services
*   Simple Networking
*   Load balancing
*   Monitoring and Troubleshooting

[github.com/cilium/cilium](https://github.com/cilium/cilium)  
HTTP, gRPC, and Kafka Aware Security and Networking for Containers with BPF and XDP [Cilium Getting Started Guides](http://docs.cilium.io/en/doc-1.0/gettingstarted/) ここでは [Getting Started Using Minikube](http://docs.cilium.io/en/doc-1.0/gettingstarted/minikube/) をなぞってみます

### Linux (ubuntu)

今回は Windows で試すんだけどメモ

#### kubectl のインストール

[Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)```
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubectl

```

#### minikube のインストール

[Releases · kubernetes/minikube](https://github.com/kubernetes/minikube/releases) からバイナリを取ってくるだけ```
curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.26.1/minikube-linux-amd64 \\
  && chmod +x minikube && sudo mv minikube /usr/local/bin/

```

### Windows

#### kubectl のインストール

```
curl -Lo ~/bin/kubectl.exe \\
  https://storage.googleapis.com/kubernetes-release/release/v1.10.0/bin/windows/amd64/kubectl.exe

```

#### minikube のインストール

```
curl -Lo ~/bin/minikube.exe \\
  https://github.com/kubernetes/minikube/releases/download/v0.26.1/minikube-windows-amd64

```

#### minikube で kubernetes 環境をセットアップ

メモリを4GBにし RBAC を有効にして構築します```
minikube start \\
  --vm-driver=virtualbox \\
  --network-plugin=cni \\
  --bootstrapper=localkube \\
  --memory=4096 \\
  --extra-config=apiserver.Authorization.Mode=RBAC

``````
Starting local Kubernetes v1.10.0 cluster...
Starting VM...
Downloading Minikube ISO
 150.53 MB / 150.53 MB  100.00% 0sss
Getting VM IP address...
WARNING: The localkube bootstrapper is now deprecated and support for it
will be removed in a future release. Please consider switching to the kubeadm bootstrapper, which
is intended to replace the localkube bootstrapper. To disable this message, run
\[minikube config set ShowBootstrapperDeprecationNotification false\]
Moving files into cluster...
Downloading localkube binary
 173.54 MB / 173.54 MB  100.00% 0sss
 65 B / 65 B  100.00% 0s
Setting up certs...
Connecting to cluster...
Setting up kubeconfig...
Starting cluster components...
Kubectl is now configured to use the cluster.
Loading cached images from config file.

```(localkube bootstrapper は deprecated で kubeadm bootstrapper 使おうねって WARNING が出てるな) `kubectl get cs` で componentstatuses を確認```
$ kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}

```全部 Healthy なので構築できてるようです `RBAC` の有効な環境で `kube-dns` サービスを有効にできるよう Kubernetes のシステムアカウントを `cluster-admin` ロールに紐づけます```
$ kubectl create clusterrolebinding kube-system-default-binding-cluster-admin \\
  --clusterrole=cluster-admin \\
  --serviceaccount=kube-system:default
clusterrolebinding.rbac.authorization.k8s.io "kube-system-default-binding-cluster-admin" created

```[standalone-etcd.yaml](https://github.com/cilium/cilium/blob/doc-1.0/examples/kubernetes/addons/etcd/standalone-etcd.yaml) で Cilium 用の etcd サービスを作成します```
$ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/kubernetes/addons/etcd/standalone-etcd.yaml
service "etcd-cilium" created
statefulset.apps "etcd-cilium" created

``````
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                    READY     STATUS    RESTARTS   AGE
default       etcd-cilium-0                           1/1       Running   0          54s
kube-system   kube-addon-manager-minikube             1/1       Running   0          3m
kube-system   kube-dns-6dcb57bcc8-g58kh               3/3       Running   0          2m
kube-system   kubernetes-dashboard-5498ccf677-9xgdz   1/1       Running   3          2m
kube-system   storage-provisioner                     1/1       Running   0          2m

```[cilium.yaml](https://github.com/cilium/cilium/blob/doc-1.0/examples/kubernetes/1.10/cilium.yaml) で cilium サービスとそれに必要な ConfigMap や Secret、ServiceAccount、ClusterRole などを作成します```
$ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/kubernetes/1.10/cilium.yaml
configmap "cilium-config" created
secret "cilium-etcd-secrets" created
daemonset.apps "cilium" created
clusterrolebinding.rbac.authorization.k8s.io "cilium" created
clusterrole.rbac.authorization.k8s.io "cilium" created
serviceaccount "cilium" created

````ContainerCreating` なので `Running` になるまでしばらく待つ```
$ kubectl get pods --namespace kube-system
NAME                                    READY     STATUS              RESTARTS   AGE
cilium-rg6dc                            0/1       ContainerCreating   0          47s
kube-addon-manager-minikube             1/1       Running             0          6m
kube-dns-6dcb57bcc8-g58kh               3/3       Running             0          5m
kubernetes-dashboard-5498ccf677-9xgdz   1/1       Running             3          5m
storage-provisioner                     1/1       Running             0          5m

```起動しました```
$ kubectl get pods --namespace kube-system
NAME                                    READY     STATUS    RESTARTS   AGE
cilium-rg6dc                            0/1       Running   0          1m
kube-addon-manager-minikube             1/1       Running   0          6m
kube-dns-6dcb57bcc8-g58kh               3/3       Running   0          6m
kubernetes-dashboard-5498ccf677-9xgdz   1/1       Running   3          6m
storage-provisioner                     1/1       Running   0          6m

```次に [http-sw-app.yaml](https://github.com/cilium/cilium/blob/doc-1.0/examples/minikube/http-sw-app.yaml) を使って [cilium/starwars](https://hub.docker.com/r/cilium/starwars/) イメージを使った deathstar サービス (コンテナ2つ) と [tgraf/netperf](https://hub.docker.com/r/tgraf/netperf/) イメージを使った tiefighter と xwing というコンテナ (Deployment) を作成します```
$ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/minikube/http-sw-app.yaml
service "deathstar" created
deployment.apps "deathstar" created
deployment.apps "tiefighter" created
deployment.apps "xwing" created

````Running` になるまでしばらく待つ```
$ kubectl get pods,svc
NAME                          READY     STATUS              RESTARTS   AGE
deathstar-765fd545f9-grr5g    0/1       ContainerCreating   0          46s
deathstar-765fd545f9-pk9h8    0/1       ContainerCreating   0          46s
etcd-cilium-0                 1/1       Running             0          5m
tiefighter-787b4ff698-kpmgl   0/1       ContainerCreating   0          46s
xwing-d56b5c5-sdw7q           0/1       ContainerCreating   0          45s

NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                           AGE
deathstar     ClusterIP   10.105.66.9      <none>        80/TCP                            46s
etcd-cilium   NodePort    10.109.105.129   <none>        32379:31079/TCP,32380:31080/TCP   5m
kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP                           8m

````Running` に変わった```
$ kubectl get pods,svc
NAME                          READY     STATUS    RESTARTS   AGE
deathstar-765fd545f9-grr5g    1/1       Running   0          3m
deathstar-765fd545f9-pk9h8    1/1       Running   0          3m
etcd-cilium-0                 1/1       Running   0          8m
tiefighter-787b4ff698-kpmgl   1/1       Running   0          3m
xwing-d56b5c5-sdw7q           1/1       Running   0          3m

NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                           AGE
deathstar     ClusterIP   10.105.66.9      <none>        80/TCP                            3m
etcd-cilium   NodePort    10.109.105.129   <none>        32379:31079/TCP,32380:31080/TCP   8m
kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP                           11m

```Cilium の Pod 名確認```
$ kubectl -n kube-system get pods -l k8s-app=cilium
NAME           READY     STATUS    RESTARTS   AGE
cilium-rg6dc   1/1       Running   0          6m

````kubectl exec` で Cilium Pod 内で `cilium endpoint list` コマンドを実行するとエンドポイントの一覧が表示されます。deathstar が2つ、tiefighter、xwing が1つずつ```
$ kubectl -n kube-system exec cilium-rg6dc cilium endpoint list
ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key\[=value\])               IPv6                 IPv4            STATUS
           ENFORCEMENT        ENFORCEMENT                                                           
173        Disabled           Disabled          64509      k8s:class=deathstar                       f00d::a0f:0:0:ad     10.15.42.252    ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=empire                           
13949      Disabled           Disabled          44856      k8s:class=tiefighter                      f00d::a0f:0:0:367d   10.15.193.100   ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=empire                           
29381      Disabled           Disabled          61850      k8s:class=xwing                           f00d::a0f:0:0:72c5   10.15.13.37     ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=alliance                         
29898      Disabled           Disabled          51604      reserved:health                           f00d::a0f:0:0:74ca   10.15.242.54    ready
48896      Disabled           Disabled          64509      k8s:class=deathstar                       f00d::a0f:0:0:bf00   10.15.167.158   ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=empire

```xwing から deathstar に curl でアクセスしてみる```
$ kubectl exec xwing-d56b5c5-sdw7q -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

```tiefighter から deathstar に curl でアクセスしてみる```
$ kubectl exec tiefighter-787b4ff698-kpmgl -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

```どちらもアクセス可能でした [sw\_l3\_l4\_policy.yaml](https://github.com/cilium/cilium/blob/doc-1.0/examples/minikube/sw_l3_l4_policy.yaml) を使って Cilium のルールを作成します `description: "L3-L4 policy to restrict deathstar access to empire ships only"` にあるように deathstar の ingress に制限をいれます。label で org=empire となっている接続元からのみ port 80 へのアクセスを許可します```
$ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/minikube/sw\_l3\_l4\_policy.yaml
ciliumnetworkpolicy.cilium.io "rule1" created

```xwing は org=alliance であるため deathstar にアクセスできなくなりました```
$ kubectl exec xwing-d56b5c5-sdw7q -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing

```つながらない 再度 endpoint list を確認します deathstar の `POLICY (ingress) ENFORCEMENT` が `Enabled` になってます```
$ kubectl -n kube-system exec cilium-rg6dc cilium endpoint list
ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key\[=value\])               IPv6                 IPv4            STATUS
           ENFORCEMENT        ENFORCEMENT                                                           
173        Enabled            Disabled          64509      k8s:class=deathstar                       f00d::a0f:0:0:ad     10.15.42.252    ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=empire                           
13949      Disabled           Disabled          44856      k8s:class=tiefighter                      f00d::a0f:0:0:367d   10.15.193.100   ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=empire                           
29381      Disabled           Disabled          61850      k8s:class=xwing                           f00d::a0f:0:0:72c5   10.15.13.37     ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=alliance                         
29898      Disabled           Disabled          51604      reserved:health                           f00d::a0f:0:0:74ca   10.15.242.54    ready
48896      Enabled            Disabled          64509      k8s:class=deathstar                       f00d::a0f:0:0:bf00   10.15.167.158   ready
                                                           k8s:io.kubernetes.pod.namespace=default  
                                                           k8s:org=empire

```cnp (CiliumNetworkPolicy) を確認```
$ kubectl get cnp
NAME      AGE
rule1     4m

```Describe で詳細確認```
$ kubectl describe cnp rule1
Name:         rule1
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  cilium.io/v2
Kind:         CiliumNetworkPolicy
Metadata:
  Cluster Name:
  Creation Timestamp:  2018-05-08T16:09:44Z
  Generation:          1
  Resource Version:    1177
  Self Link:           /apis/cilium.io/v2/namespaces/default/ciliumnetworkpolicies/rule1
  UID:                 391b40cd-52da-11e8-8ef9-080027a11e00
Spec:
  Endpoint Selector:
    Match Labels:
      Any : Class:  deathstar
      Any : Org:    empire
  Ingress:
    From Endpoints:
      Match Labels:
        Any : Org:  empire
    To Ports:
      Ports:
        Port:      80
        Protocol:  TCP
Status:
  Nodes:
    Minikube:
      Enforcing:              true
      Last Updated:           2018-05-08T16:09:52.34442593Z
      Local Policy Revision:  7
      Ok:                     true
Events:                       <none>

```続いて L7 での制限です tiefighter (org=empire) からでも許可したくないエンドポイントが deathstar にあるかもしれません、たとえば次の `/v1/exhaust-port` とか```
$ kubectl exec tiefighter-787b4ff698-kpmgl -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
Panic: deathstar exploded

goroutine 1 \[running\]:
main.HandleGarbage(0x2080c3f50, 0x2, 0x4, 0x425c0, 0x5, 0xa)
        /code/src/github.com/empire/deathstar/
        temp/main.go:9 +0x64
main.main()
        /code/src/github.com/empire/deathstar/
        temp/main.go:5 +0x85

```[sw\_l3\_l4\_l7\_policy.yaml](https://github.com/cilium/cilium/blob/doc-1.0/examples/minikube/sw_l3_l4_l7_policy.yaml) で L7 で制御してみます org=empire でかつ `/v1/request-landing` への `POST` だけを許可するという Rule です```
$ kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/minikube/sw\_l3\_l4\_l7\_policy.yaml
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
ciliumnetworkpolicy.cilium.io "rule1" configured

```tiefighter から `/v1/request-landing` へはアクセスできました```
$ kubectl exec tiefighter-787b4ff698-kpmgl -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

```が、`/v1/exhaust-port` では Access denied となりました```
$ kubectl exec tiefighter-787b4ff698-kpmgl -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
Access denied

```また cnp (CiliumNetworkPolicy) を確認しておきます```
$ kubectl get ciliumnetworkpolicies
NAME      AGE
rule1     9m

``````
$ kubectl describe ciliumnetworkpolicies rule1
Name:         rule1
Namespace:    default
Labels:       <none>
Annotations:  kubectl.kubernetes.io/last-applied-configuration={"apiVersion":"cilium.io/v2","description":"L7 policy to restrict access to specific HTTP call","kind":"CiliumNetworkPolicy","metadata":{"annotations":...
API Version:  cilium.io/v2
Kind:         CiliumNetworkPolicy
Metadata:
  Cluster Name:
  Creation Timestamp:  2018-05-08T16:09:44Z
  Generation:          1
  Resource Version:    1709
  Self Link:           /apis/cilium.io/v2/namespaces/default/ciliumnetworkpolicies/rule1
  UID:                 391b40cd-52da-11e8-8ef9-080027a11e00
Spec:
  Endpoint Selector:
    Match Labels:
      Any : Class:  deathstar
      Any : Org:    empire
  Ingress:
    From Endpoints:
      Match Labels:
        Any : Org:  empire
    To Ports:
      Ports:
        Port:      80
        Protocol:  TCP
      Rules:
        Http:
          Method:  POST
          Path:    /v1/request-landing
Status:
  Nodes:
    Minikube:
      Enforcing:              true
      Last Updated:           2018-05-08T16:17:44.124075147Z
      Local Policy Revision:  11
      Ok:                     true
Events:                       <none>

```Cilium Pod 内で `cilium policy get` として確認することもできるようです```
$ kubectl -n kube-system exec cilium-rg6dc cilium policy get
\[
  {
    "endpointSelector": {
      "matchLabels": {
        "any:class": "deathstar",
        "any:org": "empire",
        "k8s:io.kubernetes.pod.namespace": "default"
      }
    },
    "ingress": \[
      {
        "fromEndpoints": \[
          {
            "matchLabels": {
              "any:org": "empire",
              "k8s:io.kubernetes.pod.namespace": "default"
            }
          }
        \],
        "toPorts": \[
          {
            "ports": \[
              {
                "port": "80",
                "protocol": "TCP"
              }
            \],
            "rules": {
              "http": \[
                {
                  "path": "/v1/request-landing",
                  "method": "POST"
                }
              \]
            }
          }
        \]
      }
    \],
    "labels": \[
      {
        "key": "io.cilium.k8s.policy.name",
        "value": "rule1",
        "source": "unspec"
      },
      {
        "key": "io.cilium.k8s.policy.namespace",
        "value": "default",
        "source": "unspec"
      }
    \]
  }
\]
Revision: 11

```

#### Prometheus 連携

[prometheus.yaml](https://github.com/cilium/cilium/blob/doc-1.0/examples/kubernetes/prometheus.yaml) (document と path が変わってた) で Prometheus サービスをセットアップします。kubernetes service discovery で cilium コンテナを動的に見つけて cilium-agent から polling するようです```
$ kubectl create -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/kubernetes/prometheus.yaml
namespace "prometheus" created
service "prometheus" created
deployment.extensions "prometheus-core" created
configmap "prometheus-core" created
clusterrolebinding.rbac.authorization.k8s.io "prometheus" created
clusterrole.rbac.authorization.k8s.io "prometheus" created
serviceaccount "prometheus-k8s" created
configmap "cilium-metrics-config" created

```Cilium の再起動```
$ kubectl replace --force -f https://raw.githubusercontent.com/cilium/cilium/doc-1.0/examples/kubernetes/1.10/cilium.yaml
configmap "cilium-config" deleted
secret "cilium-etcd-secrets" deleted
daemonset.apps "cilium" deleted
clusterrolebinding.rbac.authorization.k8s.io "cilium" deleted
clusterrole.rbac.authorization.k8s.io "cilium" deleted
serviceaccount "cilium" deleted
configmap "cilium-config" replaced
secret "cilium-etcd-secrets" replaced
daemonset.apps "cilium" replaced
clusterrolebinding.rbac.authorization.k8s.io "cilium" replaced
clusterrole.rbac.authorization.k8s.io "cilium" replaced
serviceaccount "cilium" replaced

```

#### 後片付け

```
$ minikube delete
Deleting local Kubernetes cluster...
Machine deleted.

```

### まとめ

詳しい仕組みは確認してないけど Label を使って送信元、送信先を指定でき、L4, L7 でアクセス制御できる便利ツールだった この方のブロクを見ると BPF について理解が深まるだろうか [LinuxのBPF : (1) パケットフィルタ - 睡分不足 - mm\_i - はてなブログ](http://mmi.hatenablog.com/entry/2016/08/01/031233)