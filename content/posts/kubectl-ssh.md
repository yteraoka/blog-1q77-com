---
title: 'kubernetes に deploy 済みの Container に root で入っていじりたい'
date: Sun, 10 May 2020 14:47:38 +0000
draft: false
tags: ['Kubernetes']
---

コンテナへの権限は必要最低限に絞るべしということで、プロセスの実行ユーザーは root ではないし、特権モードで動かすなんことにはなっていないと思います。それでも調査などのために root で入って調査用コマンド追加したり tcpdump したりしたくなることがあります。Pod の設定変更して deploy し直すとかすれば良かったりもしますが面倒ですし、場合によってはプロセスの実行ユーザーを変更するのは意外と厄介かもしれません。

そこで deploy 済みのコンテナに root で横入りする方法ないかな？って調べました。

ググれば解決する問題は楽ちんだ "[bash - Exec commands on kubernetes pods with root access - Stack Overflow](https://stackoverflow.com/questions/42793382/exec-commands-on-kubernetes-pods-with-root-access)" にありました。

Runtime は Docker 前提です。他は知らない。

まずは node 上の docker の ID を取得します。今回は Istio sidecar に入ろうと思うので container name を "istio-proxy" と指定しています。

jsonpath で取り出す方法

```
$ kubectl get pod -n secure-server httpbin-8475c5b859-pclvs \
  -o jsonpath='{.status.containerStatuses[?(@.name == "istio-proxy")].containerID}' 
docker://ccf2251464b35df7954587b7f1ba7a1c6215df35f05ae52f75b8796cf475e719
```

jq の方が慣れてるよって場合

```
$ kubectl get pod -n secure-server httpbin-8475c5b859-pclvs -o json \
  | jq -r '.status.containerStatuses[] | select(.name == "istio-proxy") | .containerID'
docker://ccf2251464b35df7954587b7f1ba7a1c6215df35f05ae52f75b8796cf475e719
```

次に、この Pod が稼働している node に ssh などでログインします。minikube であれば `minikube ssh` コマンドでいける。

`docker exec` に `-u root` を付ければ root ユーザーでアクセスできますが、これだけでは tcpdump とか iptables いじったりできないので `--privileged` もつけます。

```
$ docker exec -it -u root --privileged ccf2251464b35df7954587b7f1ba7a1c6215df35f05ae52f75b8796cf475e719 /bin/bash
```

```
root@httpbin-8475c5b859-pclvs:/# id
uid=0(root) gid=0(root) groups=0(root),1337(istio-proxy)
```

普通に `kubectl exec` すると istio-proxy ユーザーになります。（ここではどうでも良い話ですが Istio は UID が重要です）

```
istio-proxy@httpbin-8475c5b859-pclvs:/$ id
uid=1337(istio-proxy) gid=1337(istio-proxy) groups=1337(istio-proxy)
```

root では入れたけど、ファイルシステムが Read-Only でマウントされていたら？

```
root@httpbin-8475c5b859-pclvs:/# mount | awk '{if ($3 == "/") {print $0}}'
overlay on / type overlay (ro,relatime,lowerdir=/var/lib/docker/overlay2/l/...(略)
root@httpbin-8475c5b859-pclvs:/# touch /tmp/hoge
touch: cannot touch '/tmp/hoge': Read-only file system
```

こんな時には remount です。

```
root@httpbin-8475c5b859-pclvs:/# mount -o rw,remount /
root@httpbin-8475c5b859-pclvs:/# mount | awk '{if ($3 == "/") {print $0}}'
overlay on / type overlay (rw,relatime,lowerdir=/var/lib/docker/overlay2/l/...(略)
root@httpbin-8475c5b859-pclvs:/# touch /tmp/hoge
root@httpbin-8475c5b859-pclvs:/# ls -l /tmp/hoge
-rw-r--r-- 1 root root 0 May 10 14:33 /tmp/hoge
```

書き込めるようになりました。これで後は好きにできる。

で、この一連の作業を一発でやってくれる便利コマンドが [kubectl-plugins](https://github.com/jordanwilson230/kubectl-plugins) にある [kubectl-ssh](https://github.com/jordanwilson230/kubectl-plugins/blob/master/kubectl-ssh) です。ssh っていう名前なんですが ssh は使ってません。docker.sock をマウントする Pod を対象となる Pod が稼働している Node に deploy してその中で `docker exec` を実行します。終わったら Pod の削除もやってくれます。はぁ、なるほどねぇって感じです。

```
Usage: kubectl ssh [OPTIONS] [-- ]
Run a command in a running container
Options:
  -h  Show usage
  -d  Enable debug mode. Print a trace of each commands
  -n  If present, the namespace scope for this CLI request
  -u  Username or UID (format: [:])
  -c  Container name. If omitted, the first container in the pod will be chosen 
```

それでは良い kubernetes debug ライフを...
