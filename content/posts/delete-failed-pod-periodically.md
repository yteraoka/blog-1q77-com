---
title: 'Graceful Node Shutdown で Terminated 状態で残る Pod を削除する cronjob'
date: Fri, 12 Aug 2022 21:19:57 +0900
draft: false
tags: ['Kubernetes', 'Kubernetes']
---

GKE (GKE 限定な話ではないけれども) で Preemptible な node を使用していると Graceful Node Shutdown により停止させられた Pod が Failed 状態でどんどん溜まっていって結構邪魔です。

できれば消えて欲しい。

ということで削除するための cronjob を deploy するための Helm chart を書いてみた。

https://github.com/yteraoka/terminated-pod-cleaner

kubectl と jq コマンドを使った shell script で [bitnami の image](https://hub.docker.com/r/bitnami/kubectl) を使わせてもらっている。

Pod の中から何も設定せずに kubectl コマンドが実行できる理由については「[Kubernetesクラスター内のPodからkubectlを実行する - Qiita](https://qiita.com/sotoiwa/items/aff12291957d85069a76)」に丁寧な解説があった。ありがとうございます。

[descheduler](https://github.com/kubernetes-sigs/descheduler) でもできるみたい。
