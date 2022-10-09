---
title: 'Self-hosted Kubernetes'
date: Tue, 11 Sep 2018 16:06:54 +0000
draft: false
tags: ['Kubernetes', 'kubeadm']
---

🐵 去る 2018年9月7日、[Tech-on MeetUp#02「マネージドサービスだけに頼らないコンテナ基盤」](https://techplay.jp/event/689676) に参加してオンプレ Kubernetes 他の話を聞いてきた。司会の方の登壇者いじりが浮いていた… というはどうでも良くって、時代は Self-hosted Kubernetes だということらしい

CoreOS の blog では2016年8月時点ですでに self-hosted について述べられています [Self-Hosted Kubernetes makes Kubernetes installs, scaleouts, upgrades easier | CoreOS](https://coreos.com/blog/self-hosted-kubernetes.html) Kubernetes の更新が簡単になり、High Availability 化も容易であると

私も先日から `kubeadm` を使った Kubernetes 構築を試してみたりしているわけですが、`kubeadm` もゆくゆくは self-hosted となる予定のようです

現在はまだ alpha 段階ですが [kubeadm init](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/) で

(`--feature-gates=SelfHosting=true` というオプションを指定することで self-hosted な control plane が構築できるようです

> If `kubeadm init` is invoked with the alpha self-hosting feature enabled, (`--feature-gates=SelfHosting=true`), the static Pod based control plane is transformed into a [self-hosted control plane](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#self-hosting).

> As of 1.8, you can experimentally create a self-hosted Kubernetes control plane. This means that key components such as the API server, controller manager, and scheduler run as [DaemonSet pods](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) configured via the Kubernetes API instead of [static pods](https://kubernetes.io/docs/tasks/administer-cluster/static-pod/) configured in the kubelet via static files.

`/etc/kubernetes/manifests/` 配下に Kubernetes Control plane の各コンポーネント用 manifest ファイルを配置する Static pods ではなく、etcd に情報をもつ DaemonSet pods として起動させます

まだ alpha 版であるためいくつか重要な制限事項があるようです

> Self-hosting in 1.8 has some important limitations. In particular, a self-hosted cluster cannot recover from a reboot of the master node without manual intervention. This and other limitations are expected to be resolved before self-hosting graduates from alpha.

マスターノードの再起動時には手動オペレー所のが必要

> By default, self-hosted control plane Pods rely on credentials loaded from hostPath volumes. Except for initial creation, these credentials are not managed by kubeadm. You can use `--feature-gates=StoreCertsInSecrets=true` to enable an experimental mode where control plane credentials are loaded from Secrets instead. This requires very careful control over the authentication and authorization configuration for your cluster, and may not be appropriate for your environment.

デフォルトでは credential を hostPath ボリュームから読むようになっているが、これは初期構築時を覗いて kubeadm では管理されない。`--feature-gates=StoreCertsInSecrets=true` オプションを使うことで Secrets の中に置くことができるが、これを行う場合、クラスタの認証認可を厳重に管理する必要がでてくる

> In kubeadm 1.8, the self-hosted portion of the control plane does not include etcd, which still runs as a static Pod.

kubeadm 1.8 においては etcd は static Pod のままである。1.8 よりも新しいものだと違うのかな？

引用したドキュメントは Kubernetes 1.11 のものです。

今度 `--feature-gates=SelfHosting=true` を試してみよう。
