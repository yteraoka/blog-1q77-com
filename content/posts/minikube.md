---
title: 'Minikube を試す'
date: 
draft: true
tags: ['未分類']
---

Kubernetes 1.3 がリリースされました [Five Days of Kubernetes 1.3](http://blog.kubernetes.io/2016/07/five-days-of-kubernetes-1.3.html) [Kubernetes 1.3: Bridging Cloud Native and Enterprise Workloads](http://blog.kubernetes.io/2016/07/kubernetes-1.3-bridging-cloud-native-and-enterprise-workloads.html) ここに What's New がありました

* オートスケールのサポート
* データセンターをまたいだクラスタ間の連携をサポート
* ステートフルアプリケーションのサポート ([Pet Set](http://kubernetes.io/docs/user-guide/petset/)）
* rkt と container standards OCI & CNI をサポート
* [ダッシュボード](https://github.com/kubernetes/dashboard)の更新

着実に便利になっていってますね。構築・運用が楽かどうかが気になります。（これまでのところ大変そうだなと思って避けている、GKE で使うものだという認識） でもちょっと試してみたい気持ちはあるので Minikube とやらを試してみます。環境は Ubuntu 16.04 Minikube: easily run Kubernetes locally

```
$ curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube \
  && sudo mv minikube /usr/local/bin/
```

```
$ minikube 
Minikube is a CLI tool that provisions and manages single-node Kubernetes clusters optimized for development workflows.

Usage:
  minikube [command]

Available Commands:
  dashboard   Opens/displays the kubernetes dashboard URL for your local cluster
  delete      Deletes a local kubernetes cluster.
  docker-env  sets up docker env variables; similar to '$(docker-machine env)'
  ip          Retrieve the IP address of the running cluster.
  logs        Gets the logs of the running localkube instance, used for debugging minikube, not user code.
  service     Gets the kubernetes URL for the specified service in your local cluster
  ssh         Log into or run a command on a machine with SSH; similar to 'docker-machine ssh'
  start       Starts a local kubernetes cluster.
  status      Gets the status of a local kubernetes cluster.
  stop        Stops a running local kubernetes cluster.
  version     Print the version of minikube.

Flags:
      --alsologtostderr[=false]: log to standard error as well as files
  -h, --help[=false]: help for minikube
      --log-flush-frequency=5s: Maximum number of seconds between log flushes
      --log_backtrace_at=:0: when logging hits line file:N, emit a stack trace
      --log_dir="": If non-empty, write log files in this directory
      --logtostderr[=false]: log to standard error instead of files
      --show-libmachine-logs[=false]: Whether or not to show logs from libmachine.
      --stderrthreshold=2: logs at or above this threshold go to stderr
      --v=0: log level for V logs
      --vmodule=: comma-separated list of pattern=N settings for file-filtered logging

Use "minikube [command] --help" for more information about a command.
```

```
$ minikube start
There is a newer version of minikube available (v0.6.0).  Download it here:
https://github.com/kubernetes/minikube/releases/tag/v0.6.0
To disable this notification, add WantUpdateNotification: False to the json config file at /home/ytera/.minikube/config
(you may have to create the file config.json in this folder if you have no previous configuration)\nStarting local Kubernetes cluster...
Kubernetes is available at https://192.168.99.100:443.
Kubectl is now configured to use the cluster.
```

https://192.168.99.100:443 なんて表示されますが、ブラウザでアクセスするものではなく API のエンドポイントです。

```
$ kubectl run hello-minikube --image=gcr.io/google_containers/echoserver:1.4 --hostport=8000 --port=8080
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

```
$ kubectl config use-context minikube
switched to context "minikube".
```

```
$ kubectl run hello-minikube --image=gcr.io/google_containers/echoserver:1.4 --hostport=8000 --port=8080
deployment "hello-minikube" created
```

```
$ kubectl get pod
NAME                              READY     STATUS    RESTARTS   AGE
hello-minikube-3383150820-94pgw   1/1       Running   0          3m
```
