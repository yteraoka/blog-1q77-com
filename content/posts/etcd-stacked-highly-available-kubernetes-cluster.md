---
title: 'etcd stacked Highly Available Kubernetes cluster を Ansible でセットアップ'
date: Mon, 20 Aug 2018 14:51:27 +0000
draft: false
tags: ['Kubernetes', 'kubeadm']
---

[Creating Highly Available Clusters with kubeadm](https://kubernetes.io/docs/setup/independent/high-availability/) の [Stacked control plane nodes](https://kubernetes.io/docs/setup/independent/high-availability/#stacked-control-plane-nodes) で etcd を control-plane に相乗りさせる kubernetes cluster の作成を試します。今回も DigitalOcean で CentOS 7 を使います。

また、面倒なので Ansible Playbook でセットアップするようにしました [github.com/yteraoka/do-k8s-stacked-etcd](https://github.com/yteraoka/do-k8s-stacked-etcd)
