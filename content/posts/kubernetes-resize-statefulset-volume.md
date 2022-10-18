---
title: "Kubernetes で StatefulSet の Volume を resize する"
date: 2022-10-18T22:36:49+09:00
draft: false
tags: ['Kubernetes']
---

Kubernetes で StatefulSet に volumeClaimTemplates を指定して Persistent Volume を使用している環境で volume のサイズを変更する方法。

素直に StatefulSet の manifest を変更して apply しようとすると次のように StatefulSet で更新可能なのは `replicas`, `template`, `updateStragety` だけだよとエラーになります。

> Error: UPGRADE FAILED: cannot patch "{NAME}" with kind StatefulSet: StatefulSet.apps "{NAME}" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'template', and 'updateStrategy' are forbidden


## Persistent Volume のサイズ変更

Kubernetes 1.11 以降 (1.14 までは Pod の停止が必要) Persistent Volume (PV) のサイズは Persistent Volume Claim (PVC) の `spec.resources.requests.storage` を変更したら PV のサイズが更新されます。

### StorageClass の対応

前提として PV, PVC で使用している **StorageClass** で `allowVolumeExpansion` が `true` になっている必要がある。

環境によってはデフォルトで有効になっている。

```
$ kubectl get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
premium-rwo          pd.csi.storage.gke.io   Delete          WaitForFirstConsumer   true                   280d
standard (default)   kubernetes.io/gce-pd    Delete          Immediate              true                   280d
standard-rwo         pd.csi.storage.gke.io   Delete          WaitForFirstConsumer   true                   280d
```

古くから使用しているクラスタでは **StorageClass** に `allowVolumeExpansion` を追加する必要があるかもしれない。

### Persistent Volume Claim の更新

Volume を resize する場合は PV ではなく PVC を編集すると、自動で Volume を拡張してくれる。縮小には対応しない。

この用途で PV を直接いじってはいけない。

`kubectl patch` コマンドで更新する場合は次のようにすることができる

```bash
kubectl patch pvc PVC_NAME -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

これで PV の size が拡張されます。


## ファイルシステムの拡張

Block Device の場合、通常は File System の拡張も必要になります。

Kubernetes 1.24 からは Online File System Resizing が有効になっており、自動で File System も拡張されるようですが、それより古い Kubernetes では Pod の再作成が必要になります。

それまでの間 PVC の status の capacity は変更前のままで conditions に `type` が `FileSystemResizePending` というものが入っています。

```yaml
status:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  conditions:
  - lastProbeTime: null
    lastTransitionTime: "2022-10-18T09:34:06Z"
    message: Waiting for user to (re-)start a pod to finish file system resize of
      volume on node.
    status: "True"
    type: FileSystemResizePending
  phase: Bound
```

`kubectl delete pod` で Pod を消して再作成すれば File System が拡張されて PVC の状態も正常になります。


## StatefulSet の volumeClaimTemplates の更新

StatefulSet から作成された PVC を変更してやれば、それぞれの volume のサイズを拡張することは可能ですが、その後 replicas を変更した場合には拡張前の size の volume が作られてしまいます。
できれば StatefulSet の volumeClaimTemplates の値も更新したいところです。ですが、冒頭で述べたように volumeClaimTemplates の変更は拒否されてしまいます。

StatefulSet ですから当然まるっと削除して作り直したくはないわけです。

こんな時に使える技が `kubectl delete` の `--cascade=orphan` です。(昔は `--cascade=false` だったみたい)

次のように実行すると StatefulSet から作成された Pod は残したまま StatefulSet を削除してくれるので

```
kubectl delete sts STATEFULSET_NAME --cascade=orphan
```

この後に再度 StatefulSet の manifest を apply してやれば Pod や volume を削除せずに StatefulSet を更新することができます。
