---
title: 'Litmus 入門'
date: Tue, 24 Nov 2020 15:37:50 +0000
draft: false
tags: ['Chaos Engineering', 'Kubernetes', 'Litmus']
---

[Chaos Mesh](https://github.com/chaos-mesh/chaos-mesh) を[少しかじっていました](https://medium.com/sreake-jp/chaos-mesh-%E3%81%AB%E3%82%88%E3%82%8B%E3%82%AB%E3%82%AA%E3%82%B9%E3%82%A8%E3%83%B3%E3%82%B8%E3%83%8B%E3%82%A2%E3%83%AA%E3%83%B3%E3%82%B0-46fa2897c742)が、最近話題の [Litmus](https://litmuschaos.io/) に入門してみます。Litmus には Chaos Mesh にはなかった [EC2 Instance の停止](https://docs.litmuschaos.io/docs/Kubernetes-Chaostoolkit-AWS/)や [Docker Daemon の停止](https://docs.litmuschaos.io/docs/docker-service-kill/)や [kubelet の停止](https://docs.litmuschaos.io/docs/kubelet-service-kill/)などができるのが魅力ですね。 (その後 Chaos Mesh でも EC2 や GCE のインスタンス停止などもできるようになっています)

商用 Chaos Engineering ツールを提供している Gremlin が [Chaos Engineering tools comparison](https://www.gremlin.com/community/tutorials/chaos-engineering-tools-comparison/) というドキュメントを公開してくれていて、触ったことがあるものは納得感のある説明でした。Litmus は確かに面倒、Chaos Mesh がセキュリティ的に良くないというのもわかるが、そもそも Production で使おうなどとは思っていなかった。

以下、minikube v1.15.1 での Kubernetes 1.18.8 と litmus 1.10.0 で試しました。

インストール
------

[Helm](https://github.com/litmuschaos/litmus-helm) もありますが、今回は [manifest](https://litmuschaos.github.io/litmus/litmus-operator-v1.10.0.yaml) をそのまま適用しました。

```
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v1.10.0.yaml
```

**litmus** Namespace に **chaos-operator-cd** Deployment とそれ用の **litmus** ServiceAccount と CRD が3つ (**chaosengines.litmuschaos.io**, **chaosexperiments.litmuschaos.io**, **chaosresults.litmuschaos.io**) 作成されます。

nginx の deploy
--------------

[Pod Delete Experiment](https://docs.litmuschaos.io/docs/pod-delete/) を実行するために、delete 対象となる Deployment を deploy します。

`helm create` コマンドで nginx の deployment 用の chart が作成されるのでこれを使います。

```
kubectl create namespace nginx
helm create nginx
cd nginx
helm install nginx . -n nginx --set replicaCount=3
```

これで replicas 3 の nginx Deployment がデプロイされます。

```
❯ kubectl get pod -n nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-577ccbcdd5-hsdpj   1/1     Running   0          165m
nginx-577ccbcdd5-lvrrk   1/1     Running   0          165m
nginx-577ccbcdd5-z97jr   1/1     Running   0          165m
```

Chaos Experiments のインストール
-------------------------

Litmus では experiment を実行する各 namespace に [chaosexperiment](https://hub.litmuschaos.io/api/chaos/1.10.0?file=charts/generic/experiments.yaml) をインストールする必要があるようです。

```
kubectl apply -f "https://hub.litmuschaos.io/api/chaos/1.10.0?file=charts/generic/experiments.yaml" -n nginx
```

```
❯ kubectl get chaosexperiments -n nginx
NAME                      AGE
container-kill            22h
disk-fill                 22h
disk-loss                 22h
docker-service-kill       22h
k8-pod-delete             22h
k8-service-kill           22h
kubelet-service-kill      22h
node-cpu-hog              22h
node-drain                22h
node-io-stress            22h
node-memory-hog           22h
node-taint                22h
pod-autoscaler            22h
pod-cpu-hog               22h
pod-delete                22h
pod-io-stress             22h
pod-memory-hog            22h
pod-network-corruption    22h
pod-network-duplication   22h
pod-network-latency       22h
pod-network-loss          22h
```

今回使うのは pod-delete だけですけどね。

Pod Delete Experiment 実行用の ServiceAccount を作成
---------------------------------------------

pod-delete 用の ServiceAccount を作成します。pod-delete に限定しなくてもこの namespace で使う experiment 用の権限を一つにまとめてしまっても良いと思いますけど、まあ今回は pod-delete しかしないので。

```
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-delete-sa
  namespace: nginx
  labels:
    name: pod-delete-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-delete-sa
  namespace: nginx
  labels:
    name: pod-delete-sa
rules:
- apiGroups: ["","litmuschaos.io","batch","apps"]
  resources: ["pods","deployments","pods/log","events","jobs","chaosengines","chaosexperiments","chaosresults"]
  verbs: ["create","list","get","patch","update","delete","deletecollection"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-delete-sa
  namespace: nginx
  labels:
    name: pod-delete-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-delete-sa
subjects:
- kind: ServiceAccount
  name: pod-delete-sa
  namespace: nginx
EOF
```

Experiment 対象となるように Deployment に annotation を設定する
-------------------------------------------------

勝手に experiment 対象とされないようにアプリ (Deployment) のオーナーが `litmuschaos.io/chaos="true"` という annotation をつけないと対象とならないようになっています。安全ですね、と思いかけたけど ChaosEngine リソースの `annotationCheck` を `false` にしたらそんなの無視するみたいです...

```
kubectl annotate deploy/nginx litmuschaos.io/chaos="true" -n nginx
```

これが設定されていないと **Unable to filter app by specified info**, **Chaos stopped due to failed app identification** とすぐに終了してしまいます (kubectl get events より)。

```
0s          Normal    ChaosEngineInitialized         chaosengine/nginx-chaos              nginx-chaos-runner created successfully
0s          Warning   ChaosResourcesOperationFailed   chaosengine/nginx-chaos              Unable to filter app by specified info
0s          Warning   ChaosEngineStopped              chaosengine/nginx-chaos              Chaos stopped due to failed app identification
```

ChaosEngine リソースの作成
-------------------

ようやく準備ができたので ChaosEngine リソースを作成することでやっと Pod の delete を行うことができます。**applabel** の値は今回の helm でデプロイした nginx にはついていない label であるため変更しました。

```
kubectl apply -f - <<EOF
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: nginx-chaos
  namespace: nginx
spec:
  appinfo:
    appns: 'nginx'
    applabel: 'app.kubernetes.io/name=nginx'  # 'app=nginx' から変更
    appkind: 'deployment'
  # It can be true/false
  annotationCheck: 'true'
  # It can be active/stop
  engineState: 'active'
  #ex. values: ns1:name=percona,ns2:run=nginx
  auxiliaryAppInfo: ''
  chaosServiceAccount: pod-delete-sa
  monitoring: false
  # It can be delete/retain
  jobCleanUpPolicy: 'delete'
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            # set chaos duration (in sec) as desired
            - name: TOTAL_CHAOS_DURATION
              value: '30'

            # set chaos interval (in sec) as desired
            - name: CHAOS_INTERVAL
              value: '10'
              
            # pod failures without '--force' & default terminationGracePeriodSeconds
            - name: FORCE
              value: 'false'
EOF
```

これを apply すると次のような状況になります。まず、nginx-chaos-runner という Pod が起動され、そこから pod-delete-xxxxxx という Job が作成され pod-delete-xxxxxx-zzzzz という Pod が起動されて label にマッチする Pod を delete します。

```
❯ kubectl get pod -n nginx
NAME                      READY   STATUS              RESTARTS   AGE
nginx-577ccbcdd5-8spjq    1/1     Running             0          4m14s
nginx-577ccbcdd5-g5xsb    0/1     ContainerCreating   0          2s
nginx-577ccbcdd5-l9mqr    1/1     Running             0          4m23s
nginx-577ccbcdd5-qwk6g    0/1     Terminating         0          7m53s
nginx-chaos-runner        1/1     Running             0          13s
pod-delete-o04orr-k4xm6   1/1     Running             0          10s
```

対象選択の `appinfo` の `appns`, `appkind` は見たままですが、 `applabel` ですこしハマりました。`appkind` で指定された Deployment の label にもマッチする必要があるし、そこから作成され、実際に削除される Pod もこの label にマッチする必要がありました。

Deployment の label にマッチしない場合は nginx-chaos-runner がすぐさま終了します。Deployment にはマッチしたが Pod にはマッチしなかった場合は pod-delete-xxxxxx-zzzzz という Pod が3分ほど待機してマッチする Pod が現れるのを待ちます。それでも現れない場合は **Application status check failed, err: Unable to find the pods with matching labels, err: <nil>** というエラーで終了します。

ChaosEngine の env で指定されている値は [Supported Experiment Tunables](https://docs.litmuschaos.io/docs/pod-delete/#supported-experiment-tunables) に説明があります。ここで使われているものはコメントが入っていますが **TOTAL\_CHAOS\_DURATION** はこの期間(秒) Pod の削除が繰り返されるという意味で、削除と削除の間隔が **CHAOS\_INTERVAL** (秒) です。

**TOTAL\_CHAOS\_DURATION** (秒) 経過すると pod-delete-xxxxxx-zzzzz という Pod も pod-delete-xxxxxx という Job も nginx-chaos-runner という Pod も終了します。`jobCleanUpPolicy` が `delete` であれば消えます。大した情報は入っていませんが、ChaosResult というリソースが作成されます。

```
❯ kubectl get chaosresult -n nginx
NAME                     AGE
nginx-chaos-pod-delete   6h25m
```

終了すると `engineState` が `stop` になっています。これを再度 `active` に書き換えると再度実行されます。

以上。他の Experiment や [Litmus Portal](https://github.com/litmuschaos/litmus/tree/master/litmus-portal) ([User Guide](https://docs.google.com/document/d/1fiN25BrZpvqg0UkBCuqQBE7Mx8BwDGC8ss2j2oXkZNA/edit)) や [Litmus Probes](https://docs.litmuschaos.io/docs/litmus-probe/) も気になりますね。ただ、Chaos Mesh と比べるとだいぶ面倒。

[YouTube](https://www.youtube.com/watch?v=X3JvY_58V9A) に動画がありました。
