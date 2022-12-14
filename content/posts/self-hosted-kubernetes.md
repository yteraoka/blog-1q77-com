---
title: 'Self-hosted Kubernetes'
date: Tue, 11 Sep 2018 16:06:54 +0000
draft: false
tags: ['Kubernetes', 'kubeadm']
---

ðµ å»ã 2018å¹´9æ7æ¥ã[Tech-on MeetUp#02ãããã¼ã¸ããµã¼ãã¹ã ãã«é ¼ããªãã³ã³ããåºç¤ã](https://techplay.jp/event/689676) ã«åå ãã¦ãªã³ãã¬ Kubernetes ä»ã®è©±ãèãã¦ãããå¸ä¼ã®æ¹ã®ç»å£èããããæµ®ãã¦ããâ¦ ã¨ããã¯ã©ãã§ãè¯ãã£ã¦ãæä»£ã¯ Self-hosted Kubernetes ã ã¨ãããã¨ããã

CoreOS ã® blog ã§ã¯2016å¹´8ææç¹ã§ãã§ã« self-hosted ã«ã¤ãã¦è¿°ã¹ããã¦ãã¾ã [Self-Hosted Kubernetes makes Kubernetes installs, scaleouts, upgrades easier | CoreOS](https://coreos.com/blog/self-hosted-kubernetes.html) Kubernetes ã®æ´æ°ãç°¡åã«ãªããHigh Availability åãå®¹æã§ããã¨

ç§ãåæ¥ãã `kubeadm` ãä½¿ã£ã Kubernetes æ§ç¯ãè©¦ãã¦ã¿ãããã¦ããããã§ããã`kubeadm` ãããããã¯ self-hosted ã¨ãªãäºå®ã®ããã§ã

ç¾å¨ã¯ã¾ã  alpha æ®µéã§ãã [kubeadm init](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/) ã§

(`--feature-gates=SelfHosting=true` ã¨ãããªãã·ã§ã³ãæå®ãããã¨ã§ self-hosted ãª control plane ãæ§ç¯ã§ããããã§ã

> If `kubeadm init` is invoked with the alpha self-hosting feature enabled, (`--feature-gates=SelfHosting=true`), the static Pod based control plane is transformed into a [self-hosted control plane](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#self-hosting).

> As of 1.8, you can experimentally create a self-hosted Kubernetes control plane. This means that key components such as the API server, controller manager, and scheduler run as [DaemonSet pods](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) configured via the Kubernetes API instead of [static pods](https://kubernetes.io/docs/tasks/administer-cluster/static-pod/) configured in the kubelet via static files.

`/etc/kubernetes/manifests/` éä¸ã« Kubernetes Control plane ã®åã³ã³ãã¼ãã³ãç¨ manifest ãã¡ã¤ã«ãéç½®ãã Static pods ã§ã¯ãªããetcd ã«æå ±ããã¤ DaemonSet pods ã¨ãã¦èµ·åããã¾ã

ã¾ã  alpha çã§ããããããã¤ãéè¦ãªå¶éäºé ãããããã§ã

> Self-hosting in 1.8 has some important limitations. In particular, a self-hosted cluster cannot recover from a reboot of the master node without manual intervention. This and other limitations are expected to be resolved before self-hosting graduates from alpha.

ãã¹ã¿ã¼ãã¼ãã®åèµ·åæã«ã¯æåãªãã¬ã¼æã®ãå¿è¦

> By default, self-hosted control plane Pods rely on credentials loaded from hostPath volumes. Except for initial creation, these credentials are not managed by kubeadm. You can use `--feature-gates=StoreCertsInSecrets=true` to enable an experimental mode where control plane credentials are loaded from Secrets instead. This requires very careful control over the authentication and authorization configuration for your cluster, and may not be appropriate for your environment.

ããã©ã«ãã§ã¯ credential ã hostPath ããªã¥ã¼ã ããèª­ãããã«ãªã£ã¦ããããããã¯åææ§ç¯æãè¦ãã¦ kubeadm ã§ã¯ç®¡çãããªãã`--feature-gates=StoreCertsInSecrets=true` ãªãã·ã§ã³ãä½¿ããã¨ã§ Secrets ã®ä¸­ã«ç½®ããã¨ãã§ãããããããè¡ãå ´åãã¯ã©ã¹ã¿ã®èªè¨¼èªå¯ãå³éã«ç®¡çããå¿è¦ãã§ã¦ãã

> In kubeadm 1.8, the self-hosted portion of the control plane does not include etcd, which still runs as a static Pod.

kubeadm 1.8 ã«ããã¦ã¯ etcd ã¯ static Pod ã®ã¾ã¾ã§ããã1.8 ãããæ°ãããã®ã ã¨éãã®ããªï¼

å¼ç¨ãããã­ã¥ã¡ã³ãã¯ Kubernetes 1.11 ã®ãã®ã§ãã

ä»åº¦ `--feature-gates=SelfHosting=true` ãè©¦ãã¦ã¿ããã
